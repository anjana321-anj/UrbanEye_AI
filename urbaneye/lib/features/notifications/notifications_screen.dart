import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/notifications_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/ue_widgets.dart';
import '../reports/report_detail_screen.dart';
import '../waste/waste_screens.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsController>();
    final now = DateTime.now();
    final today = n.items.where((x) => now.difference(x.at).inHours < 24).toList();
    final earlier = n.items.where((x) => now.difference(x.at).inHours >= 24).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Notifications')),
        actions: [
          if (n.unread > 0)
            TextButton(
              onPressed: () {
                n.markAllRead();
                Haptics.light();
              },
              child: Text(context.t('Mark all read')),
            ),
          IconButton(
            tooltip: context.t('Notification preferences'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showNotificationPreferences(context),
          ),
        ],
      ),
      body: n.loading && n.items.isEmpty
          ? const Padding(padding: EdgeInsets.all(20), child: LoadingSkeleton())
          : n.items.isEmpty
              ? const EmptyState(kind: EmptyKind.notifications)
              : RefreshIndicator(
                  onRefresh: n.load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                    if (today.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.fromLTRB(4, 8, 0, 10), child: Text(context.t('TODAY'), style: AppText.overline(context))),
                      for (var i = 0; i < today.length; i++) FadeSlideIn(index: i, child: _NotificationCard(item: today[i])),
                    ],
                    if (earlier.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.fromLTRB(4, 16, 0, 10), child: Text(context.t('EARLIER'), style: AppText.overline(context))),
                      for (var i = 0; i < earlier.length; i++) FadeSlideIn(index: i + today.length, child: _NotificationCard(item: earlier[i])),
                    ],
                    const SizedBox(height: 10),
                    Center(child: Text(context.t('Swipe a notification to mark it as read.'), style: AppText.caption(context))),
                  ]),
                ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final ctrl = context.read<NotificationsController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('n-${item.id}-${item.read}'),
        direction: item.read ? DismissDirection.none : DismissDirection.horizontal,
        confirmDismiss: (_) async {
          ctrl.markRead(item);
          Haptics.light();
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(color: ue.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Icon(Icons.mark_email_read_outlined, color: ue.success),
        ),
        child: AppCard(
          onTap: () {
            ctrl.markRead(item);
            if (item.reportId != null) {
              context.push(ReportDetailScreen(reportId: item.reportId!));
            } else if (item.type == NotificationType.pickupScheduled || item.type == NotificationType.truckApproaching) {
              final active = context.read<WasteController>().active;
              if (active != null) context.push(PickupTrackingScreen(pickupId: active.id));
            }
          },
          color: item.read ? null : (context.isDark ? ue.surfaceAlt : const Color(0xFFF2F6FF)),
          padding: const EdgeInsets.all(14),
          semanticLabel: '${item.read ? '' : 'Unread. '}${item.title}. ${item.body}',
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(icon: item.type.icon, color: item.type.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(context.t(item.title),
                        style: AppText.label(context).copyWith(fontWeight: item.read ? FontWeight.w600 : FontWeight.w800)),
                  ),
                  Text(Fmt.relative(item.at), style: AppText.caption(context).copyWith(fontSize: 10.5)),
                ]),
                const SizedBox(height: 3),
                Text(item.body, style: AppText.bodySm(context).copyWith(fontSize: 13)),
              ]),
            ),
            if (!item.read) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: ue.secondary, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

Future<void> showNotificationPreferences(BuildContext context) {
  return showUeSheet(context, builder: (ctx) {
    return Consumer<SettingsController>(builder: (ctx, s, _) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ctx.t('Notification preferences'), style: AppText.h3(ctx)),
        const SizedBox(height: 4),
        Text(ctx.t('Choose what UrbanEye can notify you about.'), style: AppText.caption(ctx)),
        const SizedBox(height: 10),
        for (final e in s.notificationPrefs.entries)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(ctx.t(e.key), style: AppText.label(ctx)),
            value: e.value,
            onChanged: (v) => s.setNotificationPref(e.key, v),
          ),
      ]);
    });
  });
}
