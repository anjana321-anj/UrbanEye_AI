const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();
const FV = admin.firestore.FieldValue;

const CODES = { 'Illegal Parking': 'PARKING', 'Waste': 'WASTE', 'Street Light': 'STREETLIGHT', 'Road': 'ROAD', 'Water & Drainage': 'WATER', 'Illegal Construction': 'CONSTRUCTION' };
const DEPTS = ['Parking', 'Waste Management', 'Streetlight', 'Road', 'Water & Drainage', 'Illegal Construction'];
const EMAIL_RE = /^[\w.+-]+@[\w-]+\.[\w.-]+$/;

// US-56: score from urgency, severity, merged count, upvotes.
const score = (r) => (r.isUrgent ? 50 : 0) + (r.severity || 1) * 10 + ((r.reporterCount || 1) - 1) * 5 + (r.upvotes || 0) * 2;

function haversine(a, b, c, d) {
  const R = 6371000, t = (x) => (x * Math.PI) / 180;
  const dLat = t(c - a), dLng = t(d - b);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(t(a)) * Math.cos(t(c)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function requireRole(req, roles) {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  const u = (await db.doc(`users/${req.auth.uid}`).get()).data();
  if (!u || !u.isActive || !roles.includes(u.role)) throw new HttpsError('permission-denied', 'Access Denied');
  return u;
}

async function notify(uids, title, body, reportId) {
  for (const uid of [...new Set(uids)]) {
    await db.collection(`notifications/${uid}/items`).add({ title, body, reportId, isRead: false, createdAt: FV.serverTimestamp() });
    const u = (await db.doc(`users/${uid}`).get()).data();
    const tokens = (u && u.fcmTokens) || [];
    if (tokens.length) await admin.messaging().sendEachForMulticast({ tokens, notification: { title, body }, data: { reportId } }).catch(() => {});
  }
}

// US-11 + US-56: tracking ID (atomic counter) and initial score.
exports.onReportCreated = onDocumentCreated('reports/{id}', async (event) => {
  const r = event.data.data();
  const year = new Date().getFullYear();
  const key = `${CODES[r.category] || 'GEN'}_${year}`;
  const ref = db.doc(`counters/${key}`);
  const n = await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const next = (s.exists ? s.data().count : 0) + 1;
    tx.set(ref, { count: next });
    return next;
  });
  await event.data.ref.update({ trackingId: `UE-${CODES[r.category] || 'GEN'}-${year}-${String(n).padStart(5, '0')}`, priorityScore: score(r) });
});

exports.onReportUpdated = onDocumentUpdated('reports/{id}', async (event) => {
  const b = event.data.before.data(), a = event.data.after.data(), id = event.params.id;
  const ref = event.data.after.ref;
  // Recalculate priority when upvotes / merges / severity / urgency change.
  const s = score(a);
  if (s !== a.priorityScore) { await ref.update({ priorityScore: s }); return; }
  // Status change: notify ALL reporters (incl. merged) + propagate to merged docs.
  if (b.status !== a.status) {
    await notify(a.reporterIds || [a.reporterId], `Report ${a.trackingId}`, `Status updated to ${a.status}`, id);
    for (const m of a.mergedReportIds || []) await db.doc(`reports/${m}`).update({ status: a.status, rejectionReason: a.rejectionReason || null }).catch(() => {});
  }
  // US-14: sanitized public mirror (no reporterId/phone/email) once Verified.
  const visible = a.status !== 'Submitted' && a.status !== 'Rejected';
  const pub = db.doc(`public_feed/${id}`);
  if (visible) {
    await pub.set({ trackingId: a.trackingId, category: a.category, subCategory: a.subCategory, status: a.status, mediaUrls: a.mediaUrls, location: a.location,
      reporterName: a.isAnonymous ? 'Anonymous Citizen' : a.reporterName, isAnonymous: a.isAnonymous, upvotes: a.upvotes, reporterCount: a.reporterCount,
      priorityScore: a.priorityScore, isUrgent: a.isUrgent, severity: a.severity, timeline: (a.timeline || []).map(({ stage, timestamp, updatedByName, remarks }) => ({ stage, timestamp, updatedByName: updatedByName || '', remarks })), createdAt: a.createdAt, description: a.description });
  } else await pub.delete().catch(() => {});
});

// US-63: new comment notifications (reports/{id}/comments/{cid}).
exports.onComment = onDocumentCreated('reports/{id}/comments/{cid}', async (event) => {
  const r = (await db.doc(`reports/${event.params.id}`).get()).data();
  const c = event.data.data();
  await notify((r.reporterIds || []).filter((u) => u !== c.authorId), `New comment on ${r.trackingId}`, c.text || '', event.params.id);
});

// US-55: suggestions - same category, <=50 m, <=7 days.
exports.findDuplicates = onCall(async (req) => {
  await requireRole(req, ['department_admin', 'super_admin']);
  const r = (await db.doc(`reports/${req.data.reportId}`).get()).data();
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - 7 * 864e5);
  const snap = await db.collection('reports').where('category', '==', r.category).where('createdAt', '>=', since).get();
  return snap.docs.filter((d) => d.id !== req.data.reportId && !d.data().mergedInto)
    .map((d) => ({ id: d.id, trackingId: d.data().trackingId, status: d.data().status, distance: haversine(r.location.lat, r.location.lng, d.data().location.lat, d.data().location.lng) }))
    .filter((d) => d.distance <= 50).sort((x, y) => x.distance - y.distance);
});

exports.mergeReports = onCall(async (req) => {
  await requireRole(req, ['department_admin', 'super_admin']);
  const { primaryId, mergeIds } = req.data;
  const pref = db.doc(`reports/${primaryId}`);
  const p = (await pref.get()).data();
  let ids = new Set(p.reporterIds || []), up = p.upvotes || 0;
  for (const m of mergeIds) {
    const d = (await db.doc(`reports/${m}`).get()).data();
    (d.reporterIds || []).forEach((u) => ids.add(u));
    up += d.upvotes || 0;
    await db.doc(`reports/${m}`).update({ mergedInto: primaryId, status: p.status });
  }
  await pref.update({ reporterIds: [...ids], reporterCount: ids.size, mergedReportIds: FV.arrayUnion(...mergeIds), upvotes: up, updatedAt: FV.serverTimestamp() }); // triggers rescoring
  return { ok: true };
});

// US-65: add admin, send invitation email (needs "Trigger Email from Firestore" extension on `mail`).
exports.addDepartmentAdmin = onCall(async (req) => {
  await requireRole(req, ['super_admin']);
  const { email, department, assignedWards = [] } = req.data;
  if (!EMAIL_RE.test(email || '')) throw new HttpsError('invalid-argument', 'Invalid email format');
  if (!DEPTS.includes(department)) throw new HttpsError('invalid-argument', 'Unknown department');
  const dup = await db.collection('department_admins').where('email', '==', email.toLowerCase()).get();
  if (!dup.empty) throw new HttpsError('already-exists', 'This email is already an admin');
  let user;
  try { user = await admin.auth().getUserByEmail(email); } catch { user = await admin.auth().createUser({ email }); }
  await db.doc(`users/${user.uid}`).set({ email: email.toLowerCase(), role: 'department_admin', department, assignedWards, isActive: true, name: '', fcmTokens: [], createdAt: FV.serverTimestamp() }, { merge: true });
  await db.doc(`department_admins/${user.uid}`).set({ email: email.toLowerCase(), department, assignedWards, isActive: true, invitedAt: FV.serverTimestamp() });
  const link = await admin.auth().generateSignInWithEmailLink(email, { url: 'https://urbaneye.page.link/admin', handleCodeInApp: true, android: { packageName: 'com.urbaneye.app', installApp: true } });
  await db.collection('mail').add({ to: email, message: { subject: 'You have been invited as UrbanEye Admin', html: `<p>You were added as <b>${department}</b> admin.</p><p><a href="${link}">Sign in to UrbanEye</a></p>` } });
  return { id: user.uid };
});

exports.editDepartmentAdmin = onCall(async (req) => {
  await requireRole(req, ['super_admin']);
  const { adminId, email, assignedWards } = req.data;
  const upd = {};
  if (email) {
    if (!EMAIL_RE.test(email)) throw new HttpsError('invalid-argument', 'Invalid email format');
    const dup = await db.collection('department_admins').where('email', '==', email.toLowerCase()).get();
    if (dup.docs.some((d) => d.id !== adminId)) throw new HttpsError('already-exists', 'Duplicate email');
    upd.email = email.toLowerCase();
    await admin.auth().updateUser(adminId, { email });
  }
  if (assignedWards) upd.assignedWards = assignedWards;
  await db.doc(`department_admins/${adminId}`).update(upd);
  await db.doc(`users/${adminId}`).update(upd);
  return { ok: true };
});

async function activeCount(dept, excludeId) {
  const s = await db.collection('department_admins').where('department', '==', dept).where('isActive', '==', true).get();
  return s.docs.filter((d) => d.id !== excludeId).length;
}

exports.removeDepartmentAdmin = onCall(async (req) => {
  await requireRole(req, ['super_admin']);
  const a = (await db.doc(`department_admins/${req.data.adminId}`).get()).data();
  if (a.isActive && (await activeCount(a.department, req.data.adminId)) < 1) throw new HttpsError('failed-precondition', 'Each department needs at least one active admin');
  await db.doc(`department_admins/${req.data.adminId}`).delete();
  await db.doc(`users/${req.data.adminId}`).update({ role: 'citizen', department: null, isActive: true });
  return { ok: true };
});

// US-66: deactivate/reactivate, block login, reassign open reports to replacement.
exports.setAdminActive = onCall(async (req) => {
  await requireRole(req, ['super_admin']);
  const { adminId, isActive, replacementId } = req.data;
  const a = (await db.doc(`department_admins/${adminId}`).get()).data();
  if (!isActive) {
    if ((await activeCount(a.department, adminId)) < 1) throw new HttpsError('failed-precondition', 'Each department needs at least one active admin');
    if (!replacementId) throw new HttpsError('invalid-argument', 'Replacement admin required');
    const open = await db.collection('reports').where('assignedAdminId', '==', adminId).where('status', 'in', ['Submitted', 'Verified', 'Assigned', 'In Progress']).get();
    const batch = db.batch();
    open.docs.forEach((d) => batch.update(d.ref, { assignedAdminId: replacementId }));
    await batch.commit();
  }
  await db.doc(`department_admins/${adminId}`).update({ isActive });
  await db.doc(`users/${adminId}`).update({ isActive });
  await admin.auth().updateUser(adminId, { disabled: !isActive });
  return { ok: true };
});
