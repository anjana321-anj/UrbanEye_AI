import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/app_user.dart';
import '../models/report.dart';
import '../providers.dart';
import '../widgets/admin_count_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_bar_widget.dart';
import '../widgets/report_card.dart';

/// One dashboard serves US-15 (Parking), US-22 (Waste), US-35 (Road) and the other departments.
/// It is scoped to the admin's department (and optionally assigned wards).
class AdminDashboard extends ConsumerStatefulWidget {
  final bool workerMode;
  const AdminDashboard({super.key, this.workerMode = false});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminState();
}

class _AdminState extends ConsumerState<AdminDashboard> {
  final f = <String, String?>{};

  Future<String?> _ask(String title) async {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: Text(title), content: TextField(controller: c, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK'))]));
  }

  void _actions(Report r, AppUser me) {
    final svc = ref.read(reportServiceProvider);
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
      if (!widget.workerMode && r.status == 'Submitted') ListTile(leading: const Icon(Icons.verified), title: const Text('Verify'), onTap: () { Navigator.pop(context); svc.updateStatus(r.id, 'Verified', me); }),
      if (!widget.workerMode && r.status == 'Submitted') ListTile(leading: const Icon(Icons.cancel), title: const Text('Reject (reason required)'), onTap: () async {
        Navigator.pop(context); final reason = await _ask('Rejection reason');
        if (reason != null && reason.isNotEmpty) svc.updateStatus(r.id, 'Rejected', me, reason: reason); }),
      if (!widget.workerMode && r.category != 'Illegal Parking') ListTile(leading: const Icon(Icons.assignment_ind), title: const Text('Assign to field worker'), onTap: () async {
        Navigator.pop(context); final w = await _ask('Field worker user ID');
        if (w != null && w.isNotEmpty) svc.updateStatus(r.id, 'Assigned', me, workerId: w); }),
      for (final s in ['In Progress', 'Resolved']) ListTile(leading: const Icon(Icons.update), title: Text('Mark $s'), onTap: () { Navigator.pop(context); svc.updateStatus(r.id, s, me); }),
      if (!widget.workerMode) ListTile(leading: const Icon(Icons.merge_type), title: const Text('Find duplicates / merge'), onTap: () { Navigator.pop(context); _duplicates(r); }),
      ListTile(leading: const Icon(Icons.open_in_new), title: const Text('Open details'), onTap: () { Navigator.pop(context); context.push('/report/${r.id}'); }),
    ])));
  }

  /// US-55: suggest duplicates (server: same category, <=50m, <=7 days) and merge.
  Future<void> _duplicates(Report r) async {
    final svc = ref.read(reportServiceProvider);
    final list = await svc.duplicates(r.id);
    if (!mounted) return;
<<<<<<< HEAD
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No duplicates found')));
      return;
    }
=======
    if (list.isEmpty) return ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No duplicates found')));
>>>>>>> origin/saksham-shrestha
    final sel = <String>{};
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: const Text('Possible duplicates'),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [for (final d in list) CheckboxListTile(
        value: sel.contains(d['id']), onChanged: (v) => set(() => v! ? sel.add(d['id']) : sel.remove(d['id'])),
        title: Text('${d['trackingId']}'), subtitle: Text('${(d['distance'] as num).round()} m away • ${d['status']}'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: sel.isEmpty ? null : () async { Navigator.pop(c); await svc.merge(r.id, sel.toList()); }, child: const Text('Merge'))])));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final dept = me.department ?? '';
    final isRoad = dept == 'Road', isParking = dept == 'Parking', isWaste = dept == 'Waste Management';
    final svc = ref.read(reportServiceProvider);
    Query<Map<String, dynamic>> q = widget.workerMode
        ? FirebaseFirestore.instance.collection('reports').where('assignedWorkerId', isEqualTo: me.uid)
        : svc.department(dept);
    final subOptions = AppConstants.categories.firstWhere((c) => c.department == dept, orElse: () => AppConstants.categories.first).subs;
    return Scaffold(
      appBar: AppBar(title: Text(widget.workerMode ? 'My tasks' : '$dept Admin'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authServiceProvider).signOut())]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('${s.error}'));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          var all = s.data!.docs.map(Report.fromDoc).where((r) => me.assignedWards.isEmpty || me.assignedWards.contains(r.ward)).toList();
          final nNew = all.where((r) => r.status == 'Submitted').length;
          final nProg = all.where((r) => ['Verified', 'Assigned', 'In Progress'].contains(r.status)).length;
          final nDone = all.where((r) => r.status == 'Resolved').length;
          var list = all.where((r) =>
              (f['Ward'] == null || '${r.ward}' == f['Ward']) &&
              (f['Status'] == null || r.status == f['Status']) &&
              (f['Date'] == null || (r.createdAt != null && DateTime.now().difference(r.createdAt!).inDays <= int.parse(f['Date']!.split(' ')[0]))) &&
              (f['Type'] == null || r.subCategory == f['Type'] || r.violationType == f['Type'])).toList();
          if (isRoad) {
            list.sort((a, b) { final c = b.severity.compareTo(a.severity); return c != 0 ? c : b.upvotes.compareTo(a.upvotes); }); // US-35
          } else {
            list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore)); // US-56 default
          }
          return Column(children: [
            Row(children: [AdminCountCard(label: 'New', count: nNew, color: Colors.blue), AdminCountCard(label: 'In Progress', count: nProg, color: Colors.orange), AdminCountCard(label: 'Resolved', count: nDone, color: AppTheme.green)]),
            FilterBarWidget(
              options: {'Ward': AppConstants.wards.map((w) => '$w').toList(), 'Status': AppConstants.allStatuses, 'Date': ['1 day', '7 days', '30 days'], 'Type': subOptions},
              values: f, onChanged: (k, v) => setState(() { if (v == null) { f.remove(k); } else { f[k] = v; } })),
            Expanded(child: list.isEmpty ? const EmptyStateWidget('No reports') : ListView(children: [
              for (final r in list) Column(children: [
                ReportCard(r: r, showIdentity: true, onTap: () => _actions(r, me)),
                if (isParking && (r.plate != null || r.violationType != null)) Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: Text('Plate: ${r.plate ?? '—'}  •  ${r.violationType ?? ''}  •  ${r.createdAt ?? ''}', style: const TextStyle(fontSize: 11)))),
                if (isWaste || isRoad) Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: Text('Severity ${r.severity} • ${r.upvotes} upvotes • ${r.reporterCount} reporters', style: const TextStyle(fontSize: 11)))),
              ]),
            ])),
          ]);
        },
      ),
    );
  }
}

/// US-65 + US-66: Super Admin department admin management.
class SuperAdminScreen extends ConsumerWidget {
  const SuperAdminScreen({super.key});

  Future<void> _addDialog(BuildContext ctx, WidgetRef ref, String dept) async {
    final email = TextEditingController(), wards = TextEditingController();
    String? err;
    await showDialog(context: ctx, builder: (_) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: Text('Add admin • $dept'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: email, decoration: InputDecoration(labelText: 'Email', errorText: err)),
        TextField(controller: wards, decoration: const InputDecoration(labelText: 'Wards (e.g. 1,2,5) – blank = all')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () async {
        if (!AdminService.validEmail(email.text.trim())) return set(() => err = 'Invalid email format');
        try {
          await ref.read(adminServiceProvider).add(email.text.trim(), dept, _parseWards(wards.text));
          if (c.mounted) Navigator.pop(c);
        } catch (e) { set(() => err = e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), '')); }
      }, child: const Text('Send invite'))])));
  }

  static List<int> _parseWards(String s) => s.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();

  Future<void> _editWards(BuildContext ctx, WidgetRef ref, QueryDocumentSnapshot<Map<String, dynamic>> d) async {
    final c = TextEditingController(text: List<int>.from(d['assignedWards'] ?? []).join(','));
    await showDialog(context: ctx, builder: (_) => AlertDialog(title: const Text('Restrict to wards'), content: TextField(controller: c, decoration: const InputDecoration(hintText: '1,2,5 (blank = all)')),
      actions: [FilledButton(onPressed: () { ref.read(adminServiceProvider).edit(d.id, wards: _parseWards(c.text)); Navigator.pop(ctx); }, child: const Text('Save'))]));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Super Admin'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authServiceProvider).signOut())]),
        body: ListView(children: [
          for (final dept in AppConstants.departments) ExpansionTile(
            title: Text(dept), trailing: IconButton(icon: const Icon(Icons.person_add), onPressed: () => _addDialog(context, ref, dept)),
            children: [StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref.read(adminServiceProvider).watch(dept),
              builder: (c, s) {
                if (!s.hasData) return const LinearProgressIndicator();
                if (s.data!.docs.isEmpty) return const ListTile(title: Text('No admins yet – add at least one'));
                return Column(children: [for (final d in s.data!.docs) ListTile(
                  title: Text(d['email']), subtitle: Text('Wards: ${List.from(d['assignedWards'] ?? []).isEmpty ? 'all' : List.from(d['assignedWards']).join(', ')} • ${d['isActive'] == true ? 'Active' : 'Deactivated'}'),
                  trailing: PopupMenuButton<String>(onSelected: (v) async {
                    final svc = ref.read(adminServiceProvider);
                    try {
                      if (v == 'wards') await _editWards(context, ref, d);
                      if (v == 'toggle') await svc.setActive(d.id, d['isActive'] != true, replacementId: s.data!.docs.where((x) => x.id != d.id && x['isActive'] == true).map((x) => x.id).firstOrNull);
                      if (v == 'remove') await svc.remove(d.id);
                    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
                  }, itemBuilder: (_) => [
                    const PopupMenuItem(value: 'wards', child: Text('Restrict wards')),
                    PopupMenuItem(value: 'toggle', child: Text(d['isActive'] == true ? 'Deactivate (reassign reports)' : 'Reactivate')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ]),
                )]);
              },
            )],
          ),
        ]),
      );
}
<<<<<<< HEAD

class AdminService {
  static bool validEmail(String e) => e.contains('@');
}
=======
>>>>>>> origin/saksham-shrestha
