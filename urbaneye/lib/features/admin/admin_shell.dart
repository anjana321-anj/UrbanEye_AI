import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../state/admin_controller.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/brand.dart';
import '../../widgets/ue_widgets.dart';
import 'admin_dashboard.dart';
import 'admin_insights.dart';
import 'admin_ops.dart';
import 'admin_reports.dart';

class AdminNav extends ChangeNotifier {
  String page = 'dashboard';
  ReportCategory? category;
  String? openReportId;

  void go(String p, {ReportCategory? cat}) {
    page = p;
    category = cat;
    openReportId = null;
    notifyListeners();
  }

  void openReport(String id) {
    page = 'reports';
    openReportId = id;
    notifyListeners();
  }

  void closeReport() {
    openReportId = null;
    notifyListeners();
  }
}

class _Item {
  final String id;
  final IconData icon;
  final String label;
  final ReportCategory? cat;
  final Perm? perm;
  const _Item(this.id, this.icon, this.label, {this.cat, this.perm});
  String get key => cat == null ? id : '$id:${cat!.name}';
}

const _items = [
  _Item('dashboard', Icons.space_dashboard_outlined, 'Dashboard'),
  _Item('reports', Icons.inbox_outlined, 'Reports'),
  _Item('waste', Icons.delete_outline_rounded, 'Waste Management'),
  _Item('reports', Icons.local_parking_rounded, 'Illegal Parking', cat: ReportCategory.parking),
  _Item('reports', Icons.water_drop_outlined, 'Water Leakage', cat: ReportCategory.water),
  _Item('reports', Icons.lightbulb_outline_rounded, 'Streetlights', cat: ReportCategory.streetlight),
  _Item('reports', Icons.foundation_rounded, 'Infrastructure', cat: ReportCategory.infrastructure),
  _Item('reports', Icons.add_road_rounded, 'Road Conditions', cat: ReportCategory.road),
  _Item('users', Icons.people_outline_rounded, 'Users', perm: Perm.manageUsers),
  _Item('teams', Icons.groups_2_outlined, 'Municipality Teams'),
  _Item('analytics', Icons.insights_outlined, 'Analytics', perm: Perm.viewAnalytics),
  _Item('sla', Icons.timer_outlined, 'SLA & Escalation'),
  _Item('audit', Icons.receipt_long_outlined, 'Audit Log', perm: Perm.viewAudit),
  _Item('settings', Icons.settings_outlined, 'Settings'),
];

/// Desktop-first municipality console (1440×1024 target), responsive down to
/// tablet (rail) and phone (drawer).
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (_) => AdminNav(), child: const _AdminBody());
}

class _AdminBody extends StatelessWidget {
  const _AdminBody();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AdminNav>();
    final ac = context.watch<AdminController>();
    final w = MediaQuery.sizeOf(context).width;
    final full = w >= 1100;
    final rail = w >= 720 && !full;

    final page = KeyedSubtree(
      key: ValueKey('${nav.page}:${nav.category?.name}'),
      child: switch (nav.page) {
        'reports' => AdminReportsPage(category: nav.category),
        'waste' => const AdminWastePage(),
        'teams' => const AdminTeamsPage(),
        'analytics' => const AdminAnalyticsPage(),
        'sla' => const AdminSlaPage(),
        'audit' => const AdminAuditPage(),
        'users' => const AdminUsersPage(),
        'settings' => const AdminSettingsPage(),
        _ => const AdminDashboardPage(),
      },
    );

    return Scaffold(
      drawer: full || rail ? null : Drawer(child: SafeArea(child: _Sidebar(compact: false, onPicked: () => Navigator.pop(context)))),
      body: Row(children: [
        if (full) const SizedBox(width: 264, child: _Sidebar(compact: false)),
        if (rail) const SizedBox(width: 84, child: _Sidebar(compact: true)),
        Expanded(
          child: Column(children: [
            _TopBar(showMenu: !full && !rail),
            if (ac.loading && ac.reports.isEmpty) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.d(context, 280),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.01, 0), end: Offset.zero).animate(a), child: c),
                ),
                child: page,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool compact;
  final VoidCallback? onPicked;
  const _Sidebar({required this.compact, this.onPicked});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AdminNav>();
    final ac = context.watch<AdminController>();
    final ue = context.ue;
    final dark = context.isDark;
    final current = nav.category == null ? nav.page : '${nav.page}:${nav.category!.name}';
    final bg = dark ? const Color(0xFF081127) : AppColors.navy;
    return Container(
      color: bg,
      child: SafeArea(
        right: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 0 : 20, 20, compact ? 0 : 16, 18),
            child: compact
                ? const Center(child: BrandMark(size: 42))
                : Row(children: [
                    const BrandMark(size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Wordmark(size: 18, color: Colors.white),
                        Text('ADMIN CONSOLE', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                      ]),
                    ),
                  ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12), children: [
              for (final it in _items)
                if (it.perm == null || ac.can(it.perm!)) _tile(context, it, current == it.key, ue),
            ]),
          ),
          if (!compact)
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Row(children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF6EE7B7), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${context.t(ac.role.label)} · ${context.t('audit-logged')}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext context, _Item it, bool active, UeColors ue) {
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.62);
    final child = AnimatedContainer(
      duration: Motion.d(context, 200),
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12, vertical: 11),
      decoration: BoxDecoration(
        color: active ? AppColors.electric.withValues(alpha: 0.9) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: compact
          ? Icon(it.icon, color: fg, size: 21)
          : Row(children: [
              Icon(it.icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(context.t(it.label), style: TextStyle(color: fg, fontWeight: active ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5))),
              if (it.id == 'sla' && context.watch<AdminController>().reports.any((r) => r.escalated && r.status.isOpen))
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
            ]),
    );
    return Semantics(
      button: true,
      selected: active,
      label: context.t(it.label),
      child: Tooltip(
        message: compact ? context.t(it.label) : '',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () {
            Haptics.tap();
            context.read<AdminNav>().go(it.id, cat: it.cat);
            onPicked?.call();
          },
          child: child,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool showMenu;
  const _TopBar({required this.showMenu});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final ac = context.watch<AdminController>();
    final auth = context.watch<AuthController>();
    final s = context.watch<SettingsController>();
    final escalated = ac.reports.where((r) => r.escalated && r.status.isOpen).length;
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Container(
      padding: EdgeInsets.fromLTRB(showMenu ? 8 : 24, MediaQuery.paddingOf(context).top + 10, 20, 10),
      decoration: BoxDecoration(color: ue.surface, border: Border(bottom: BorderSide(color: ue.border))),
      child: Row(children: [
        if (showMenu)
          Builder(builder: (ctx) => IconButton(tooltip: context.t('Menu'), icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())),
        if (wide)
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.t('Search ticket ID (e.g. UE-10284)'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  fillColor: ue.background,
                ),
                onSubmitted: (q) {
                  final r = ac.reports.where((r) => r.ticket.toLowerCase() == q.trim().toLowerCase()).firstOrNull;
                  if (r != null) {
                    context.read<AdminNav>().openReport(r.id);
                  } else {
                    showToast(context, 'No report found for "$q"', kind: ToastKind.warning);
                  }
                },
              ),
            ),
          )
        else
          const Spacer(),
        if (wide) const Spacer(),
        // Role preview (demo of RBAC)
        PopupMenuButton<String>(
          tooltip: context.t('Preview as role'),
          onSelected: (v) {
            final r = v == 'self' ? null : UserRole.values.byName(v);
            ac.setRoleOverride(r);
            showToast(context, 'Viewing console as ${r?.label ?? auth.user?.role.label}', kind: ToastKind.info);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'self', child: Text('${context.t('My role')} (${auth.user?.role.label})')),
            for (final r in UserRole.values.where((r) => r.isStaff)) PopupMenuItem(value: r.name, child: Text(context.t(r.label))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(border: Border.all(color: ue.border), borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.badge_outlined, size: 16, color: ue.secondary),
              const SizedBox(width: 6),
              if (wide) Text(context.t(ac.role.label), style: AppText.label(context).copyWith(fontSize: 12)),
              const Icon(Icons.expand_more_rounded, size: 18),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        UeIconButton(
          icon: context.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: 'Toggle theme',
          onPressed: () => s.setThemeMode(context.isDark ? ThemeMode.light : ThemeMode.dark),
        ),
        const SizedBox(width: 4),
        UeIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Escalations',
          badge: escalated,
          onPressed: () => context.read<AdminNav>().go('sla'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: context.t('Account'),
          onSelected: (v) {
            if (v == 'logout') auth.logout();
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text(auth.user?.email ?? '', style: AppText.caption(context))),
            PopupMenuItem(value: 'logout', child: Row(children: [const Icon(Icons.logout_rounded, size: 18), const SizedBox(width: 8), Text(context.t('Logout'))])),
          ],
          child: UeAvatar(initials: auth.user?.initials ?? '?', size: 40),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared admin building blocks
// ---------------------------------------------------------------------------

class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const AdminPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w > 900 ? 28.0 : 16.0;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(pad, 22, pad, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 10,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Semantics(header: true, child: Text(context.t(title), style: AppText.h1(context).copyWith(fontSize: 28))),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(context.t(subtitle!), style: AppText.bodySm(context))],
            ]),
            if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 22),
        ...children,
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  final Color color;
  final String? delta;
  final bool deltaGood;
  final List<double>? spark;
  final VoidCallback? onTap;
  const KpiCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.delta, this.deltaGood = true, this.spark, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      semanticLabel: '$label: $value',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTile(icon: icon, color: color, size: 40, iconSize: 20, radius: 12),
          const Spacer(),
          if (delta != null)
            Pill(delta!, icon: deltaGood ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: deltaGood ? ue.success : ue.error),
        ]),
        const SizedBox(height: 14),
        AnimatedCounter(value: value, style: AppText.h1(context).copyWith(fontSize: 30)),
        const SizedBox(height: 2),
        Text(context.t(label), style: AppText.bodySm(context)),
      ]),
    );
  }
}

/// Responsive grid helper: picks a column count from the available width.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double? itemHeight;
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 220, this.spacing = 14, this.itemHeight});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 6).toInt();
      final w = (c.maxWidth - (cols - 1) * spacing) / cols;
      return Wrap(spacing: spacing, runSpacing: spacing, children: [
        for (final ch in children) SizedBox(width: w, height: itemHeight, child: ch),
      ]);
    });
  }
}

class PanelCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  const PanelCard({super.key, required this.title, this.subtitle, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t(title), style: AppText.title(context)),
                if (subtitle != null) Text(context.t(subtitle!), style: AppText.caption(context)),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Lightweight data table with sticky header styling and hover rows.
class AdminTable extends StatelessWidget {
  final List<String> columns;
  final List<int> flex;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final int? selectedIndex;
  const AdminTable({super.key, required this.columns, required this.flex, required this.rows, this.onRowTap, this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final total = flex.fold<int>(0, (a, b) => a + b);
    return LayoutBuilder(builder: (context, c) {
      final minW = total * 34.0;
      final width = c.maxWidth < minW ? minW : c.maxWidth;
      final table = SizedBox(
        width: width,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: ue.surfaceAlt, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Row(children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(flex: flex[i], child: Text(context.t(columns[i]).toUpperCase(), style: AppText.overline(context).copyWith(fontSize: 10.5))),
            ]),
          ),
          for (var r = 0; r < rows.length; r++)
            Material(
              color: selectedIndex == r ? ue.secondary.withValues(alpha: 0.08) : Colors.transparent,
              child: InkWell(
                onTap: onRowTap == null ? null : () => onRowTap!(r),
                hoverColor: ue.secondary.withValues(alpha: 0.04),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ue.border.withValues(alpha: 0.7)))),
                  child: Row(children: [
                    for (var i = 0; i < columns.length; i++)
                      Expanded(flex: flex[i], child: Align(alignment: Alignment.centerLeft, child: rows[r][i])),
                  ]),
                ),
              ),
            ),
        ]),
      );
      return c.maxWidth < minW ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table) : table;
    });
  }
}
