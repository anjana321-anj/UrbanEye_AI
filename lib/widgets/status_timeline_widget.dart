import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/report.dart';

/// US-12: stages with date, time, updater; rejection reason when rejected.
class StatusTimelineWidget extends StatelessWidget {
  final Report r;
  const StatusTimelineWidget(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    final done = {for (final t in r.timeline) t['stage'] as String: t};
    return Column(children: [
      for (final s in AppConstants.statuses)
        ListTile(
          dense: true,
          leading: Icon(done.containsKey(s) ? Icons.check_circle : Icons.radio_button_unchecked, color: done.containsKey(s) ? AppTheme.green : Colors.grey),
          title: Text(s, style: TextStyle(fontWeight: done.containsKey(s) ? FontWeight.bold : FontWeight.normal)),
          subtitle: done.containsKey(s)
              ? Text('${DateFormat('d MMM y, h:mm a').format((done[s]!['timestamp'] as Timestamp).toDate())}\nby ${done[s]!['updatedByName']}')
              : null,
        ),
      if (r.status == 'Rejected')
        ListTile(leading: const Icon(Icons.cancel, color: Colors.red), title: const Text('Rejected'), subtitle: Text(r.rejectionReason ?? 'No reason given')),
    ]);
  }
}
