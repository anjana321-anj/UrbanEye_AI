import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../state/notifications_controller.dart';
import '../../state/reports_controller.dart';
import '../../widgets/ue_widgets.dart';
import '../home/home_screen.dart';
import '../map/city_map_screen.dart';
import '../profile/profile_screen.dart';
import '../report/report_center_screen.dart';
import '../reports/my_reports_screen.dart';
import '../reports/report_detail_screen.dart';

class ShellNav extends ChangeNotifier {
  int index = 0;
  void go(int i) {
    if (i == index) return;
    index = i;
    notifyListeners();
  }
}

class CitizenShell extends StatelessWidget {
  const CitizenShell({super.key});

  @override
  Widget build(BuildContext context) => const _ShellBody();
}

class _ShellBody extends StatefulWidget {
  const _ShellBody();
  @override
  State<_ShellBody> createState() => _ShellBodyState();
}

class _ShellBodyState extends State<_ShellBody> {
  static const _pages = [HomeScreen(), ReportCenterScreen(), CityMapScreen(), MyReportsScreen(), ProfileScreen()];
  NotificationsController? _notifs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = context.read<NotificationsController>();
    if (_notifs != n) {
      _notifs?.removeListener(_onNotif);
      _notifs = n..addListener(_onNotif);
    }
  }

  void _onNotif() {
    final inc = _notifs?.incoming;
    if (inc == null || !mounted) return;
    _notifs!.consumeIncoming();
    Haptics.light();
    showToast(context, inc.title, kind: ToastKind.info, action: inc.reportId != null ? 'View' : null, onAction: () {
      if (inc.reportId != null) context.push(ReportDetailScreen(reportId: inc.reportId!));
    });
  }

  @override
  void dispose() {
    _notifs?.removeListener(_onNotif);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNav>();
    final rc = context.watch<ReportsController>();
    return PopScope(
      canPop: nav.index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.go(0);
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: IndexedStack(
                index: nav.index,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    _FadeIndexed(active: nav.index == i, child: _pages[i]),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 0,
            right: 0,
            child: OfflineBanner(online: rc.online, syncing: rc.syncing, progress: rc.syncProgress, queued: rc.outbox.length),
          ),
        ]),
        bottomNavigationBar: _FloatingNavBar(index: nav.index, onTap: nav.go),
      ),
    );
  }
}

/// Cross-fades a tab in when it becomes active.
class _FadeIndexed extends StatelessWidget {
  final bool active;
  final Widget child;
  const _FadeIndexed({required this.active, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: Motion.d(context, 260),
        child: AnimatedSlide(
          offset: active ? Offset.zero : const Offset(0, 0.015),
          duration: Motion.d(context, 260),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      );
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _FloatingNavBar({required this.index, required this.onTap});

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.add_a_photo_outlined, Icons.add_a_photo_rounded, 'Report'),
    _NavItem(Icons.map_outlined, Icons.map_rounded, 'Map'),
    _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'My Reports'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 14),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xE60E1830) : const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: ue.border.withValues(alpha: 0.7)),
                  boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth / _items.length;
                  return Stack(children: [
                    // Sliding active indicator
                    AnimatedPositioned(
                      duration: Motion.d(context, 380),
                      curve: Curves.easeOutBack,
                      left: w * index + (w - 52) / 2,
                      top: 9,
                      child: Container(
                        width: 52,
                        height: 34,
                        decoration: BoxDecoration(
                          color: (context.isDark ? AppColors.electric : AppColors.navy).withValues(alpha: index == 1 ? 0 : 0.1),
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                    ),
                    Row(children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(child: _NavButton(item: _items[i], active: i == index, center: i == 1, onTap: () => onTap(i))),
                    ]),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool center;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.active, required this.center, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final activeColor = context.isDark ? Colors.white : AppColors.navy;
    return Semantics(
      selected: active,
      button: true,
      label: context.t(item.label),
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        radius: 36,
        child: SizedBox.expand(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (center)
              AnimatedScale(
                scale: active ? 1.08 : 1,
                duration: Motion.d(context, 250),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.electric, AppColors.navy500]),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.glow(AppColors.electric),
                  ),
                  child: Icon(active ? item.activeIcon : item.icon, color: Colors.white, size: 22),
                ),
              )
            else ...[
              AnimatedScale(
                scale: active ? 1.12 : 1,
                duration: Motion.d(context, 250),
                curve: Curves.easeOutBack,
                child: AnimatedSwitcher(
                  duration: Motion.d(context, 200),
                  child: Icon(active ? item.activeIcon : item.icon,
                      key: ValueKey(active), color: active ? activeColor : ue.textSubtle, size: 24),
                ),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: Motion.d(context, 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? activeColor : ue.textSubtle,
                  fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                ),
                child: Text(context.t(item.label), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
