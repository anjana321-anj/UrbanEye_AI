import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../state/reports_controller.dart';
import '../../widgets/ue_widgets.dart';
import '../report/report_flow_screen.dart';

/// Locally saved drafts and offline outbox.
class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<ReportsController>();
    final ue = context.ue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Drafts & Offline'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(rc.online ? Icons.cloud_done_outlined : Icons.cloud_off_rounded, color: rc.online ? ue.success : ue.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rc.online
                    ? context.t('Online — queued reports upload automatically.')
                    : context.t('Offline — reports are stored safely on this device.'),
                style: AppText.label(context),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: rc.forcedOffline,
          onChanged: (v) {
            rc.setForcedOffline(v);
            showToast(context, v ? 'Offline mode simulated' : 'Back online — syncing', kind: v ? ToastKind.warning : ToastKind.success);
          },
          title: Text(context.t('Simulate offline mode'), style: AppText.label(context)),
          subtitle: Text(context.t('Developer tool to demonstrate offline capture and auto-upload.'), style: AppText.caption(context)),
        ),
        if (rc.syncing) ...[
          const SizedBox(height: 8),
          Text(context.t('Uploading saved reports…'), style: AppText.label(context)),
          const SizedBox(height: 6),
          UeProgressBar(value: rc.syncProgress),
        ],
        const SizedBox(height: 18),
        SectionHeader(title: 'Waiting to upload (${rc.outbox.length})'),
        const SizedBox(height: 8),
        if (rc.outbox.isEmpty)
          Text(context.t('Nothing queued.'), style: AppText.caption(context))
        else
          for (final d in rc.outbox)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  IconTile(icon: d.category?.icon ?? Icons.help_outline, color: ue.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.t(d.category?.label ?? 'Report'), style: AppText.label(context)),
                      Text('${d.location?.area ?? ''} · ${Fmt.relative(d.createdAt)}', style: AppText.caption(context)),
                    ]),
                  ),
                  Pill('Queued', icon: Icons.schedule_rounded, color: ue.warning),
                ]),
              ),
            ),
        const SizedBox(height: 18),
        SectionHeader(title: 'Drafts (${rc.drafts.length})'),
        const SizedBox(height: 8),
        if (rc.drafts.isEmpty)
          const SizedBox(height: 300, child: EmptyState(kind: EmptyKind.drafts))
        else
          for (final d in rc.drafts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey(d.localId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: ue.error, borderRadius: BorderRadius.circular(AppRadii.lg)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) {
                  rc.deleteDraft(d.localId);
                  showToast(context, 'Draft deleted');
                },
                child: AppCard(
                  onTap: () => context.push(ReportFlowScreen(draft: d)),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    IconTile(icon: d.category?.icon ?? Icons.edit_note_rounded, color: d.category?.color ?? ue.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.t(d.category?.label ?? 'Untitled report'), style: AppText.label(context)),
                        Text(
                          d.description.isEmpty ? '${d.evidence.length} ${context.t('photos')} · ${Fmt.relative(d.createdAt)}' : d.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(context),
                        ),
                      ]),
                    ),
                    Text(context.t('Continue'), style: AppText.label(context).copyWith(color: ue.secondary)),
                  ]),
                ),
              ),
            ),
        if (rc.drafts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.t('Swipe left to delete a draft.'), style: AppText.caption(context)),
          ),
      ]),
    );
  }
}
