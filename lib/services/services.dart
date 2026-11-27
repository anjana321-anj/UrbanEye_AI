import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';
import '../models/app_user.dart';

final _db = FirebaseFirestore.instance;
final _auth = FirebaseAuth.instance;

class AuthService {
  String? _verificationId;
  DateTime? _otpSentAt;
  int _wrong = 0;

  /// US-01: validates +977 mobile (98/97 prefixes, 10 digits) and sends OTP.
  static bool validNepaliNumber(String n) => RegExp(r'^9[78]\d{8}$').hasMatch(n);

  Future<void> sendOtp(String local10, {required void Function() onSent, required void Function(String) onError}) async {
    if (!validNepaliNumber(local10)) return onError('Enter a valid Nepali mobile number');
    _wrong = 0;
    await _auth.verifyPhoneNumber(
      phoneNumber: '+977$local10',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (c) => _auth.signInWithCredential(c),
      verificationFailed: (e) => onError(e.message ?? 'Failed to send OTP'),
      codeSent: (id, _) { _verificationId = id; _otpSentAt = DateTime.now(); onSent(); },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  /// Expires after 5 minutes, max 3 wrong attempts.
  Future<String?> verifyOtp(String code) async {
    if (_verificationId == null) return 'Request an OTP first';
    if (DateTime.now().difference(_otpSentAt!) > const Duration(minutes: 5)) return 'OTP expired. Request a new one.';
    if (_wrong >= 3) return 'Too many wrong attempts. Request a new OTP.';
    try {
      final cred = await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code));
      final ref = _db.collection('users').doc(cred.user!.uid);
      if (!(await ref.get()).exists) {
        await ref.set({'phone': cred.user!.phoneNumber, 'role': 'citizen', 'name': '', 'isActive': true, 'assignedWards': [], 'fcmTokens': [], 'createdAt': FieldValue.serverTimestamp()});
      }
      return null;
    } on FirebaseAuthException {
      _wrong++;
      return _wrong >= 3 ? 'Too many wrong attempts. Request a new OTP.' : 'Wrong code (${3 - _wrong} attempts left)';
    }
  }

  Future<void> sendAdminLink(String email) => _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(url: 'https://urbaneye.page.link/admin', handleCodeInApp: true, androidPackageName: 'com.urbaneye.app', androidInstallApp: true));

  Future<String?> completeAdminLink(String email, String link) async {
    if (!_auth.isSignInWithEmailLink(link)) return 'Invalid sign-in link';
    await _auth.signInWithEmailLink(email: email, emailLink: link);
    return null;
  }

  Future<void> signOut() => _auth.signOut();
}

class UserService {
  Stream<AppUser?> watch(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((d) => d.exists ? AppUser.fromMap(uid, d.data()!) : null);
}

class LocationService {
  /// US-06/07: reverse geocode + ward lookup + municipality check.
  static Future<String> address(double lat, double lng) async {
    try {
      final p = (await placemarkFromCoordinates(lat, lng)).first;
      return [p.street, p.subLocality, p.locality].where((e) => e != null && e.isNotEmpty).join(', ');
    } catch (_) { return '$lat, $lng'; }
  }

  /// PLACEHOLDER ward lookup: replace with polygon lookup from municipal GIS data.
  static int wardFor(double lat, double lng) {
    final b = AppConstants.bounds;
    final col = ((lng - b['minLng']!) / (b['maxLng']! - b['minLng']!) * 8).clamp(0, 7.99).floor();
    final row = ((lat - b['minLat']!) / (b['maxLat']! - b['minLat']!) * 4).clamp(0, 3.99).floor();
    return row * 8 + col + 1;
  }

  static bool insideMunicipality(double lat, double lng) {
    final b = AppConstants.bounds;
    return lat >= b['minLat']! && lat <= b['maxLat']! && lng >= b['minLng']! && lng <= b['maxLng']!;
  }
}

class ReportService {
<<<<<<< HEAD
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('reports');
=======
  Query<Map<String, dynamic>> get _col => _db.collection('reports');
>>>>>>> origin/saksham-shrestha

  Future<File> compress(File f) async {
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    final r = await FlutterImageCompress.compressAndGetFile(f.path, out, quality: 70, minWidth: 1280, minHeight: 1280);
    return r == null ? f : File(r.path);
  }

  /// Creates the report. trackingId + priorityScore are filled in by Cloud Functions (US-11, US-56).
  Future<String> submit({
    required AppUser user, required String category, required String subCategory, String? violationType,
    String? plate, required String description, required List<File> photos, File? video,
    required double lat, required double lng, required int ward, required String address,
    required bool anonymous, int severity = 2,
  }) async {
    final ref = _db.collection('reports').doc();
    final urls = <String>[];
    for (final f in photos) {
      final c = await compress(f);
      final s = FirebaseStorage.instance.ref('reports/${ref.id}/${urls.length}.jpg');
      await s.putFile(c);
      urls.add(await s.getDownloadURL());
    }
    if (video != null) {
      final s = FirebaseStorage.instance.ref('reports/${ref.id}/video.mp4');
      await s.putFile(video);
      urls.add(await s.getDownloadURL());
    }
    final cat = AppConstants.byName(category);
    await ref.set({
      'trackingId': 'PENDING', 'reporterId': user.uid, 'reporterName': user.name?.isNotEmpty == true ? user.name : 'Citizen',
      'isAnonymous': anonymous, 'category': category, 'subCategory': subCategory, 'violationType': violationType,
      'plateNumber': plate, 'description': description, 'mediaUrls': urls,
      'location': {'lat': lat, 'lng': lng, 'ward': ward, 'address': address},
      'status': 'Submitted', 'rejectionReason': null,
      'timeline': [{'stage': 'Submitted', 'timestamp': Timestamp.now(), 'updatedBy': user.uid, 'updatedByName': anonymous ? 'Anonymous Citizen' : (user.name ?? 'Citizen'), 'remarks': ''}],
      'isUrgent': subCategory == 'exposed wire', 'severity': severity, 'upvotes': 0, 'mergedReportIds': [],
      'reporterIds': [user.uid], 'reporterCount': 1, 'priorityScore': 0,
      'assignedDepartment': cat.department, 'assignedAdminId': null, 'assignedWorkerId': null,
      'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchOne(String id) => _col.doc(id).snapshots();
  Query<Map<String, dynamic>> mine(String uid) => _col.where('reporterIds', arrayContains: uid).orderBy('createdAt', descending: true);
  /// US-14: sanitized public mirror written by Cloud Function on verification.
  Query<Map<String, dynamic>> publicFeed() => _db.collection('public_feed').orderBy('priorityScore', descending: true);
  Query<Map<String, dynamic>> department(String dept) => _col.where('assignedDepartment', isEqualTo: dept).orderBy('priorityScore', descending: true);

  Future<void> updateStatus(String id, String status, AppUser by, {String? reason, String? workerId}) async {
    await _col.doc(id).update({
      'status': status, 'updatedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'rejectionReason': reason,
      if (workerId != null) 'assignedWorkerId': workerId,
      'timeline': FieldValue.arrayUnion([{'stage': status, 'timestamp': Timestamp.now(), 'updatedBy': by.uid, 'updatedByName': by.name ?? by.email ?? 'Admin', 'remarks': reason ?? ''}]),
    });
  }

  Future<void> upvote(String id) => _col.doc(id).update({'upvotes': FieldValue.increment(1)}); // score recalculated by function
  Future<List<Map<String, dynamic>>> duplicates(String id) async {
    final r = await FirebaseFunctions.instance.httpsCallable('findDuplicates').call({'reportId': id});
    return List<Map<String, dynamic>>.from((r.data as List).map((e) => Map<String, dynamic>.from(e)));
  }
  Future<void> merge(String primary, List<String> others) =>
      FirebaseFunctions.instance.httpsCallable('mergeReports').call({'primaryId': primary, 'mergeIds': others});
}

class AdminService {
  final _fn = FirebaseFunctions.instance;
  static bool validEmail(String e) => RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(e);
  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String dept) =>
      _db.collection('department_admins').where('department', isEqualTo: dept).snapshots();
  Future<void> add(String email, String dept, List<int> wards) => _fn.httpsCallable('addDepartmentAdmin').call({'email': email, 'department': dept, 'assignedWards': wards});
  Future<void> edit(String id, {String? email, List<int>? wards}) => _fn.httpsCallable('editDepartmentAdmin').call({'adminId': id, 'email': email, 'assignedWards': wards});
  Future<void> remove(String id) => _fn.httpsCallable('removeDepartmentAdmin').call({'adminId': id});
  Future<void> setActive(String id, bool active, {String? replacementId}) =>
      _fn.httpsCallable('setAdminActive').call({'adminId': id, 'isActive': active, 'replacementId': replacementId});
}
