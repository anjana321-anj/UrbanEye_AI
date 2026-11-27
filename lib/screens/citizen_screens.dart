import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/report.dart';
import '../providers.dart';
import '../services/services.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_bar_widget.dart';
import '../widgets/map_pin_picker.dart';
import '../widgets/media_picker_widget.dart';
import '../widgets/report_card.dart';
import '../widgets/status_timeline_widget.dart';

class CitizenHome extends ConsumerStatefulWidget {
  const CitizenHome({super.key});
  @override
  ConsumerState<CitizenHome> createState() => _CitizenHomeState();
}

class _CitizenHomeState extends ConsumerState<CitizenHome> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = [const PublicFeed(), const MyReports()];
    return Scaffold(
      appBar: AppBar(title: const Text('UrbanEye'), actions: [
        IconButton(icon: const Icon(Icons.notifications), onPressed: () => context.push('/notifications')),
        IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authServiceProvider).signOut()),
      ]),
      body: tabs[_tab],
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/citizen/submit'), icon: const Icon(Icons.add_a_photo), label: const Text('Report issue')),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.public), label: 'Public feed'),
        NavigationDestination(icon: Icon(Icons.list_alt), label: 'My reports'),
      ]),
    );
  }
}

/// US-14: verified-only feed from sanitized `public_feed` mirror; filters; no phone/email.
class PublicFeed extends ConsumerStatefulWidget {
  const PublicFeed({super.key});
  @override
  ConsumerState<PublicFeed> createState() => _PublicFeedState();
}

class _PublicFeedState extends ConsumerState<PublicFeed> {
  final f = <String, String?>{};
  @override
  Widget build(BuildContext context) => Column(children: [
        FilterBarWidget(
          options: {'Category': AppConstants.categories.map((c) => c.name).toList(), 'Ward': AppConstants.wards.map((w) => '$w').toList(), 'Status': AppConstants.allStatuses},
          values: f, onChanged: (k, v) => setState(() { if (v == null) { f.remove(k); } else { f[k] = v; } })),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.read(reportServiceProvider).publicFeed().snapshots(),
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            var list = s.data!.docs.map(Report.fromDoc).where((r) =>
                (f['Category'] == null || r.category == f['Category']) &&
                (f['Ward'] == null || '${r.ward}' == f['Ward']) &&
                (f['Status'] == null || r.status == f['Status'])).toList();
            if (list.isEmpty) return const EmptyStateWidget('No verified reports yet');
            return ListView(children: [for (final r in list) ReportCard(r: r, onTap: () => context.push('/report/${r.id}'))]);
          },
        )),
      ]);
}

/// US-11: My Reports, searchable by tracking ID.
class MyReports extends ConsumerStatefulWidget {
  const MyReports({super.key});
  @override
  ConsumerState<MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends ConsumerState<MyReports> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by tracking ID (UE-…)'), onChanged: (v) => setState(() => q = v.trim().toLowerCase()))),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.read(reportServiceProvider).mine(uid).snapshots(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final list = s.data!.docs.map(Report.fromDoc).where((r) => r.trackingId.toLowerCase().contains(q)).toList();
          if (list.isEmpty) return const EmptyStateWidget('You have not reported anything yet');
          return ListView(children: [for (final r in list) ReportCard(r: r, showIdentity: true, onTap: () => context.push('/report/${r.id}'))]);
        },
      )),
    ]);
  }
}

class SubmitReportScreen extends ConsumerStatefulWidget {
  const SubmitReportScreen({super.key});
  @override
  ConsumerState<SubmitReportScreen> createState() => _SubmitState();
}

class _SubmitState extends ConsumerState<SubmitReportScreen> {
  String? _cat, _sub, _violation;
  final _desc = TextEditingController(), _plate = TextEditingController();
  List<File> _photos = [];
  File? _video;
  LatLng? _pos;
  String _address = '';
  int _ward = 0;
  bool _anon = false, _busy = false, _outside = false;

  @override
  void initState() { super.initState(); _locate(); }

  /// US-06: permission + auto GPS; falls back to manual pin if off/denied.
  Future<void> _locate() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever || !enabled) {
      if (!mounted) return;
      _setPos(const LatLng(27.7172, 85.3240)); // Kathmandu fallback; user sets pin manually
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Location is off. Turn on GPS or set the pin manually.'), action: SnackBarAction(label: 'Settings', onPressed: Geolocator.openLocationSettings)));
      return;
    }
    final p = await Geolocator.getCurrentPosition();
    _setPos(LatLng(p.latitude, p.longitude));
  }

  Future<void> _setPos(LatLng p) async {
    final addr = await LocationService.address(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      _pos = p; _address = addr; _ward = LocationService.wardFor(p.latitude, p.longitude);
      _outside = !LocationService.insideMunicipality(p.latitude, p.longitude);
    });
  }

  Future<void> _submit() async {
    String? err;
    if (_cat == null || _sub == null) err = 'Select a category and sub-category';
    else if (_cat == 'Illegal Parking' && _violation == null) err = 'Select a violation type';
    else if (_photos.isEmpty && _video == null) err = 'Add at least one photo or video';
    else if (_pos == null) err = 'Location required';
<<<<<<< HEAD
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
=======
    if (err != null) return ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
>>>>>>> origin/saksham-shrestha
    setState(() => _busy = true);
    final user = ref.read(currentUserProvider).value!;
    try {
      final id = await ref.read(reportServiceProvider).submit(
          user: user, category: _cat!, subCategory: _sub!, violationType: _cat == 'Illegal Parking' ? _violation : null,
          plate: _plate.text.trim().isEmpty ? null : _plate.text.trim().toUpperCase(), description: _desc.text.trim(),
          photos: _photos, video: _video, lat: _pos!.latitude, lng: _pos!.longitude, ward: _ward, address: _address, anonymous: _anon,
          severity: _sub == 'exposed wire' || _sub == 'blocked road' ? 3 : 2);
      if (mounted) context.go('/citizen/success/$id');
    } catch (e) {
      if (mounted) { setState(() => _busy = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _cat == null ? null : AppConstants.byName(_cat!);
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(value: _cat, decoration: const InputDecoration(labelText: 'Category *'),
            items: [for (final c in AppConstants.categories) DropdownMenuItem(value: c.name, child: Text(c.name))],
            onChanged: (v) => setState(() { _cat = v; _sub = null; _violation = null; })),
        const SizedBox(height: 12),
        if (cat != null) DropdownButtonFormField<String>(value: _sub, decoration: InputDecoration(labelText: _cat == 'Street Light' ? 'Fault type *' : 'Sub-category *'),
            items: [for (final s in cat.subs) DropdownMenuItem(value: s, child: Text(s))], onChanged: (v) => setState(() => _sub = v)),
        if (_sub == 'exposed wire') const Padding(padding: EdgeInsets.only(top: 8), child: Text('⚠ Exposed wire will be marked URGENT.', style: TextStyle(color: Colors.red))),
        if (_cat == 'Illegal Parking') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _violation, decoration: const InputDecoration(labelText: 'Violation type *'),
              items: [for (final s in cat!.subs) DropdownMenuItem(value: s, child: Text(s))], onChanged: (v) => setState(() => _violation = v)),
          const SizedBox(height: 12),
          TextField(controller: _plate, decoration: const InputDecoration(labelText: 'Vehicle plate number')),
        ],
        const SizedBox(height: 12),
        TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12),
        const Text('Photos / video *', style: TextStyle(fontWeight: FontWeight.bold)),
        MediaPickerWidget(photos: _photos, video: _video, onChanged: (p, v) => setState(() { _photos = p; _video = v; })),
        const SizedBox(height: 12),
        const Text('Location *', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_pos == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else ...[
          MapPinPicker(position: _pos!, onChanged: _setPos),
          ListTile(dense: true, leading: const Icon(Icons.place), title: Text(_address), subtitle: Text('Ward $_ward • ${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}')),
          if (_outside) const Text('⚠ This pin is outside the municipality boundary.', style: TextStyle(color: Colors.orange)),
          TextButton.icon(onPressed: _locate, icon: const Icon(Icons.my_location), label: const Text('Use my current location')),
        ],
        SwitchListTile(title: Text(_anon ? 'Post anonymously' : 'Show my name'), subtitle: const Text('Admins can still see your identity for follow-up'), value: _anon, onChanged: (v) => setState(() => _anon = v)),
        const SizedBox(height: 8),
        CustomButton(label: 'Submit report', loading: _busy, onPressed: _submit),
      ]),
    );
  }
}

class SuccessScreen extends ConsumerWidget {
  final String reportId;
  const SuccessScreen({super.key, required this.reportId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.read(reportServiceProvider).watchOne(reportId),
          builder: (c, s) {
            final tid = s.hasData && s.data!.exists ? s.data!['trackingId'] as String : 'PENDING';
            return Column(mainAxisSize: MainAxisSize.min, children: [
              const AppLogo(height: 100),
              const Icon(Icons.check_circle, size: 72, color: Colors.green),
              const Text('Report submitted!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your tracking ID'),
              SelectableText(tid == 'PENDING' ? 'Generating…' : tid, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              CustomButton(label: 'View report', onPressed: () => context.go('/report/$reportId')),
              const SizedBox(height: 8),
              CustomButton(label: 'Back to home', outlined: true, onPressed: () => context.go('/citizen')),
            ]);
          },
        ))),
      );
}

class ReportDetailScreen extends ConsumerWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final privileged = me?.isAdmin == true || me?.isSuper == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Report details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.read(reportServiceProvider).watchOne(reportId),
        builder: (c, s) {
          if (!s.hasData || !s.data!.exists) return const Center(child: CircularProgressIndicator());
          final r = Report.fromDoc(s.data!);
          final name = r.isAnonymous && !privileged ? 'Anonymous Citizen' : r.reporterName;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (r.mediaUrls.isNotEmpty) SizedBox(height: 200, child: ListView(scrollDirection: Axis.horizontal, children: [for (final u in r.mediaUrls) Padding(padding: const EdgeInsets.only(right: 8), child: Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.videocam, size: 60)))])),
            const SizedBox(height: 12),
            Text(r.trackingId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${r.category} • ${r.subCategory}${r.violationType != null ? ' • ${r.violationType}' : ''}'),
            Text('Ward ${r.ward} • ${r.address}'),
            Text('Reported by $name • ${r.reporterCount} reporter(s) • ${r.upvotes} upvotes'),
            if (r.description.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(r.description)),
            if (privileged && r.isAnonymous) const Text('(Reported anonymously — identity visible to admins only)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            TextButton.icon(onPressed: () => ref.read(reportServiceProvider).upvote(r.id), icon: const Icon(Icons.thumb_up), label: const Text('Upvote')),
            const Divider(),
            StatusTimelineWidget(r),
          ]);
        },
      ),
    );
  }
}

/// US-63: Notification Centre.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final col = FirebaseFirestore.instance.collection('notifications').doc(uid).collection('items');
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('createdAt', descending: true).snapshots(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.docs.isEmpty) return const EmptyStateWidget('No notifications');
          return ListView(children: [for (final d in s.data!.docs) ListTile(
            leading: Icon(d['isRead'] == true ? Icons.notifications_none : Icons.notifications_active, color: Colors.blue),
            title: Text(d['title'] ?? ''), subtitle: Text(d['body'] ?? ''),
            onTap: () { d.reference.update({'isRead': true}); if (d['reportId'] != null) context.push('/report/${d['reportId']}'); },
          )]);
        },
      ),
    );
  }
}
