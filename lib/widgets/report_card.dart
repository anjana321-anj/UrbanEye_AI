import 'package:flutter/material.dart';
import '../core/constants/app_assets.dart';
import '../core/theme/app_theme.dart';
import '../models/report.dart';

class ReportCard extends StatelessWidget {
  final Report r;
  final VoidCallback? onTap;
  final bool showIdentity; // admins see real reporter; public sees Anonymous Citizen (US-09)
  const ReportCard({super.key, required this.r, this.onTap, this.showIdentity = false});
  @override
  Widget build(BuildContext context) {
    final name = r.isAnonymous && !showIdentity ? 'Anonymous Citizen' : r.reporterName;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          SizedBox(width: 100, height: 100, child: r.mediaUrls.isEmpty
              ? Image.asset(AppAssets.placeholderReport, fit: BoxFit.cover)
              : Image.network(r.mediaUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset(AppAssets.placeholderReport, fit: BoxFit.cover))),
          Expanded(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.trackingId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              if (r.isUrgent) const Icon(Icons.warning_amber, color: Colors.red, size: 18),
            ]),
            Text('${r.category} • ${r.subCategory}', maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Ward ${r.ward} • ${r.address}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              Chip(label: Text(r.status, style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: AppTheme.statusColor(r.status), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              const Spacer(),
              Text('$name${r.reporterCount > 1 ? ' +${r.reporterCount - 1}' : ''}', style: const TextStyle(fontSize: 11)),
            ]),
          ]))),
        ]),
      ),
    );
  }
}
