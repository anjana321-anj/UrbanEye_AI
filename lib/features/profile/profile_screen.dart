import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/env.dart';
import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/reports_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/ue_widgets.dart';
import '../citizen/citizen_shell.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/consent_screen.dart';
import '../report/report_components.dart';
import '../reports/drafts_screen.dart';
import '../transparency/public_dashboard_screen.dart';

// ===========================================================================
// Profile
// ===========================================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Logout', message: 'You can sign back in anytime. Drafts stay on this device.', confirm: 'Logout');
    if (!ok || !context.mounted) return;
    context.read<ShellNav>().go(0);
    context.popToRoot();
    await context.read<AuthController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final rc = context.watch<ReportsController>();
    final u = auth.user;
    final ue = context.ue;
    if (u == null) return const SizedBox();
    if (rc.state == LoadState.loading && rc.mine.isEmpty) {
      return const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(20), child: LoadingSkeleton(kind: SkeletonKind.profile))));
    }
    final c = rc.contribution;
    final resolved = rc.mine.where((r) => r.status.bucket == StatusBucket.resolved).length;
    final menu = <(IconData, String, VoidCallback)>[
      (Icons.receipt_long_outlined, 'My Reports', () => context.read<ShellNav>().go(3)),
      (Icons.notifications_none_rounded, 'Notifications', () => context.push(const NotificationsScreen())),
      (Icons.bookmark_border_rounded, 'Saved Locations', () => context.push(const SavedLocationsScreen())),
      (Icons.drafts_outlined, 'Drafts & Offline', () => context.push(const DraftsScreen())),
      (Icons.insights_outlined, 'Public Transparency Dashboard', () => context.push(const PublicDashboardScreen())),
      (Icons.settings_outlined, 'Settings', () => context.push(const SettingsScreen())),
      (Icons.help_outline_rounded, 'Help & Support', () => context.push(const HelpScreen())),
      (Icons.privacy_tip_outlined, 'Privacy', () => context.push(const PrivacyScreen())),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 120), children: [
          Row(children: [
            Expanded(child: Semantics(header: true, child: Text(context.t('Profile'), style: AppText.h1(context)))),
            UeIconButton(icon: Icons.edit_outlined, tooltip: 'Edit profile', onPressed: () => _editProfile(context, u)),
          ]),
          const SizedBox(height: 18),
          FadeSlideIn(
            child: AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                UeAvatar(initials: u.initials, size: 68),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name, style: AppText.h3(context)),
                    const SizedBox(height: 4),
                    _line(context, Icons.mail_outline_rounded, u.email),
                    _line(context, Icons.phone_outlined, Fmt.maskPhone(u.phone)),
                    _line(context, Icons.place_outlined, '${u.city}, Nepal'),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            index: 1,
            child: Row(children: [
              _stat(context, rc.mine.length, 'Reports Submitted', AppColors.electric),
              const SizedBox(width: 10),
              _stat(context, resolved, 'Reports Resolved', AppColors.emerald),
              const SizedBox(width: 10),
              _stat(context, c.score, 'Contribution Score', AppColors.violet),
            ]),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(index: 2, child: _BadgeCard(contribution: c)),
          const SizedBox(height: 18),
          for (var i = 0; i < menu.length; i++)
            FadeSlideIn(
              index: 3 + i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: menu[i].$3,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    IconTile(icon: menu[i].$1, color: ue.secondary, size: 38, iconSize: 19, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(child: Text(context.t(menu[i].$2), style: AppText.label(context))),
                    Icon(Icons.chevron_right_rounded, color: ue.textSubtle),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          UeButton(label: 'Logout', icon: Icons.logout_rounded, variant: ButtonVariant.outline, onPressed: () => _logout(context)),
          const SizedBox(height: 12),
          Center(child: Text('UrbanEye v${Env.appVersion}', style: AppText.caption(context))),
        ]),
      ),
    );
  }

  Widget _line(BuildContext context, IconData i, String t) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(i, size: 13, color: context.ue.textSubtle),
          const SizedBox(width: 5),
          Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(context))),
        ]),
      );

  Widget _stat(BuildContext context, int v, String label, Color c) => Expanded(
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            AnimatedCounter(value: v, style: AppText.h2(context).copyWith(color: c)),
            const SizedBox(height: 2),
            Text(context.t(label), textAlign: TextAlign.center, maxLines: 2, style: AppText.caption(context).copyWith(fontSize: 11)),
          ]),
        ),
      );

  Future<void> _editProfile(BuildContext context, AppUser u) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: u.name);
    final email = TextEditingController(text: u.email);
    final phone = TextEditingController(text: u.phone);
    final saved = await showUeSheet<bool>(context, builder: (ctx) {
      return Form(
        key: form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.t('Edit profile'), style: AppText.h3(ctx)),
          const SizedBox(height: 16),
          TextFormField(controller: name, validator: (v) => Validators.required(v, 'Full name'), decoration: InputDecoration(labelText: ctx.t('Full Name'))),
          const SizedBox(height: 12),
          TextFormField(controller: email, validator: Validators.email, decoration: InputDecoration(labelText: ctx.t('Email'))),
          const SizedBox(height: 12),
          TextFormField(controller: phone, validator: Validators.phone, decoration: InputDecoration(labelText: ctx.t('Phone'))),
          const SizedBox(height: 18),
          UeButton(
            label: 'Save',
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
          ),
        ]),
      );
    });
    if (saved != true || !context.mounted) return;
    final ok = await context.read<AuthController>().updateProfile(name: name.text.trim(), email: email.text.trim(), phone: phone.text.trim());
    if (!context.mounted) return;
    if (ok) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SuccessCheck(size: 100),
            const SizedBox(height: 10),
            Text(ctx.t('Profile updated'), style: AppText.h3(ctx)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('Done')))],
        ),
      );
    }
  }
}

class _BadgeCard extends StatelessWidget {
  final Contribution contribution;
  const _BadgeCard({required this.contribution});

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final b = contribution.badge;
    final next = contribution.nextThreshold;
    final progress = b == CivicBadge.champion ? 1.0 : (contribution.score / next).clamp(0.0, 1.0);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.navy500, AppColors.electric]),
              boxShadow: AppShadows.glow(AppColors.electric),
            ),
            child: const Icon(Icons.workspace_premium_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('Civic standing'), style: AppText.caption(context)),
              Text(context.t(b.label), style: AppText.title(context)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        UeProgressBar(value: progress, color: AppColors.violet),
        const SizedBox(height: 8),
        Text(
          b == CivicBadge.champion
              ? context.t('Top contributor. Thank you for keeping the city accountable.')
              : '${next - contribution.score} ${context.t('points to the next level. Points come from reports the municipality verifies and resolves.')}',
          style: AppText.caption(context),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final cb in CivicBadge.values)
            Expanded(
              child: Opacity(
                opacity: cb.index <= b.index ? 1 : 0.35,
                child: Column(children: [
                  Icon(cb.index <= b.index ? Icons.verified_rounded : Icons.lock_outline_rounded, color: ue.secondary, size: 20),
                  const SizedBox(height: 4),
                  Text(context.t(cb.label), textAlign: TextAlign.center, style: AppText.caption(context).copyWith(fontSize: 10.5)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

// ===========================================================================
// Settings
// ===========================================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final rc = context.watch<ReportsController>();
    final ue = context.ue;
    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(context.t(title).toUpperCase(), style: AppText.overline(context))),
            AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Column(children: children)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.t('Settings'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        group('Appearance', [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text(context.t('System'))),
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text(context.t('Light'))),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text(context.t('Dark'))),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.translate_rounded, color: ue.secondary),
            title: Text(context.t('Language'), style: AppText.label(context)),
            trailing: DropdownButton<String>(
              value: s.locale.languageCode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ne', child: Text('नेपाली')),
              ],
              onChanged: (v) => s.setLocale(Locale(v ?? 'en')),
            ),
          ),
        ]),
        group('Accessibility', [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Icon(Icons.format_size_rounded, color: ue.secondary),
              const SizedBox(width: 14),
              Expanded(child: Text(context.t('Text size'), style: AppText.label(context))),
              Text('${(s.textScale * 100).round()}%', style: AppText.caption(context)),
            ]),
          ),
          Slider(
            value: s.textScale,
            min: 0.9,
            max: 1.4,
            divisions: 5,
            label: '${(s.textScale * 100).round()}%',
            onChanged: s.setTextScale,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.motion_photos_off_outlined, color: ue.secondary),
            title: Text(context.t('Reduce motion'), style: AppText.label(context)),
            subtitle: Text(context.t('Minimise animations and transitions'), style: AppText.caption(context)),
            value: s.reducedMotion,
            onChanged: s.setReducedMotion,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.contrast_rounded, color: ue.secondary),
            title: Text(context.t('High contrast'), style: AppText.label(context)),
            value: s.highContrast,
            onChanged: s.setHighContrast,
          ),
        ]),
        group('Notifications', [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_active_outlined, color: ue.secondary),
            title: Text(context.t('Notification preferences'), style: AppText.label(context)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showNotificationPreferences(context),
          ),
        ]),
        group('Developer & demo', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.wifi_off_rounded, color: ue.secondary),
            title: Text(context.t('Simulate offline mode'), style: AppText.label(context)),
            value: rc.forcedOffline,
            onChanged: rc.setForcedOffline,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.widgets_outlined, color: ue.secondary),
            title: Text(context.t('States gallery (empty / error / success)'), style: AppText.label(context)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(const StatesGalleryScreen()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_clock_outlined, color: ue.secondary),
            title: Text(context.t('Simulate session expiry'), style: AppText.label(context)),
            onTap: () {
              context.read<ShellNav>().go(0);
              context.popToRoot();
              context.read<AuthController>().expireSession();
            },
          ),
        ]),
      ]),
    );
  }
}

// ===========================================================================
// Privacy
// ===========================================================================

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final ue = context.ue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Privacy'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        AppCard(
          color: ue.secondary.withValues(alpha: 0.08),
          bordered: false,
          child: Row(children: [
            Icon(Icons.shield_outlined, color: ue.secondary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.t('Your identity is visible only to authorised municipal staff handling your report. Public views show anonymised data only.'),
                style: AppText.bodySm(context).copyWith(color: ue.text),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Report anonymously by default'), style: AppText.label(context)),
              subtitle: Text(context.t('Hide your name on public views of your reports'), style: AppText.caption(context)),
              value: s.anonymousByDefault,
              onChanged: s.setAnonymousByDefault,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Approximate location'), style: AppText.label(context)),
              subtitle: Text(context.t('Round GPS to ~150 m when you are not pinning a report'), style: AppText.caption(context)),
              value: s.approximateLocation,
              onChanged: s.setApproximateLocation,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('Include my reports in public statistics'), style: AppText.label(context)),
              subtitle: Text(context.t('Aggregated and anonymised only'), style: AppText.caption(context)),
              value: s.shareStatsPublicly,
              onChanged: s.setShareStats,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(context.t('Terms, Privacy & Permissions'), style: AppText.label(context)),
              subtitle: Text(
                s.consentAt == null ? '' : '${context.t('Accepted')} ${Fmt.date(s.consentAt!)} · v${Env.consentVersion}',
                style: AppText.caption(context),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(const ConsentScreen(reviewMode: true)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: Text(context.t('Data retention'), style: AppText.label(context)),
              subtitle: Text(context.t('Reports are anonymised after {m} months', {'m': s.retentionMonths}), style: AppText.caption(context)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: Text(context.t('Download my data'), style: AppText.label(context)),
              onTap: () => showToast(context, 'We\'ll email a copy of your data within 48 hours', kind: ToastKind.success),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        UeButton(
          label: 'Delete account',
          icon: Icons.delete_forever_outlined,
          variant: ButtonVariant.danger,
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Delete account?',
              message: 'Your profile and personal data will be permanently deleted. Submitted reports stay with the municipality but are de-identified. This cannot be undone.',
              confirm: 'Delete',
              danger: true,
            );
            if (!ok || !context.mounted) return;
            final settings = context.read<SettingsController>();
            final auth = context.read<AuthController>();
            context.read<ShellNav>().go(0);
            context.popToRoot();
            await settings.clearPersonalData();
            await auth.deleteAccount();
          },
        ),
      ]),
    );
  }
}

// ===========================================================================
// Saved locations
// ===========================================================================

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});
  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  List<SavedLocation>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _uid => context.read<AuthController>().user!.id;

  Future<void> _load() async {
    final l = await Services.I.locations.savedLocations(_uid);
    if (mounted) setState(() => _items = l);
  }

  IconData _icon(String l) => switch (l) {
        'Home' => Icons.home_rounded,
        'Work' => Icons.work_rounded,
        'University' => Icons.school_rounded,
        _ => Icons.bookmark_rounded,
      };

  Future<void> _add() async {
    var label = 'Home';
    PlaceLocation? loc;
    final saved = await showUeSheet<bool>(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.t('Add saved location'), style: AppText.h3(ctx)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final l in ['Home', 'Work', 'University', 'Other'])
              ChoiceChip(avatar: Icon(_icon(l), size: 16), label: Text(ctx.t(l)), selected: label == l, onSelected: (_) => set(() => label = l)),
          ]),
          const SizedBox(height: 14),
          LocationPicker(height: 240, onChanged: (p) => loc = p),
          const SizedBox(height: 14),
          UeButton(label: 'Save', onPressed: () => Navigator.pop(ctx, true)),
        ]);
      });
    });
    if (saved != true || loc == null) return;
    await Services.I.locations.saveLocation(_uid, SavedLocation(id: 'sl-${DateTime.now().millisecondsSinceEpoch}', label: label, location: loc!));
    if (mounted) showToast(context, '$label saved', kind: ToastKind.success);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Saved Locations'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(context.t('Add')),
      ),
      body: _items == null
          ? const Padding(padding: EdgeInsets.all(20), child: LoadingSkeleton())
          : _items!.isEmpty
              ? EmptyState(kind: EmptyKind.savedLocations, actionLabel: 'Add location', onAction: _add)
              : ListView(padding: const EdgeInsets.all(20), children: [
                  Text(context.t('Saved places appear in the location search so you can report from them in one tap.'), style: AppText.caption(context)),
                  const SizedBox(height: 14),
                  for (final s in _items!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: ue.error, borderRadius: BorderRadius.circular(AppRadii.lg)),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await Services.I.locations.deleteLocation(_uid, s.id);
                          setState(() => _items!.remove(s));
                        },
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            IconTile(icon: _icon(s.label), color: ue.secondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(context.t(s.label), style: AppText.label(context)),
                                Text(s.location.address, style: AppText.caption(context)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ]),
    );
  }
}

// ===========================================================================
// Help & support
// ===========================================================================

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('How fast will my report be fixed?', 'Each report gets a response target based on severity: Critical 4 h, High 24 h, Medium 3 days, Low 7 days. Overdue reports are escalated to a supervisor automatically.'),
    ('Can I report anonymously?', 'Yes. Turn on "Report anonymously" in the report flow or set it as default in Privacy. Authorised staff can still message you in-app.'),
    ('What happens if the issue is not really fixed?', 'Open the report, answer "Issue remains" and it is reopened and sent back to the municipality with priority.'),
    ('Does it work without internet?', 'Yes. Capture photos, location and details offline; the report is saved and uploads automatically when you reconnect.'),
    ('Does the AI decide anything?', 'No. AI only suggests a category, severity and description. You confirm everything, and municipal staff review every report.'),
  ];

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Help & Support'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ue.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.emergency_rounded, color: ue.error),
              const SizedBox(width: 8),
              Text(context.t('Emergency?'), style: AppText.title(context).copyWith(color: ue.error)),
            ]),
            const SizedBox(height: 6),
            Text(context.t('UrbanEye is not an emergency service. In an emergency call 100 (Police), 101 (Fire) or 102 (Ambulance).'), style: AppText.bodySm(context).copyWith(color: ue.text)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: const [
              Pill('Police 100', icon: Icons.local_police_outlined, color: AppColors.electric),
              Pill('Fire 101', icon: Icons.local_fire_department_outlined, color: AppColors.red),
              Pill('Ambulance 102', icon: Icons.medical_services_outlined, color: AppColors.emerald),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        const SectionHeader(title: 'Frequently asked'),
        const SizedBox(height: 8),
        for (final f in _faq)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(context.t(f.$1), style: AppText.label(context)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [Text(context.t(f.$2), style: AppText.bodySm(context))],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        UeButton(
          label: 'Contact Support',
          icon: Icons.support_agent_rounded,
          variant: ButtonVariant.secondary,
          onPressed: () => showToast(context, 'Support chat opened — typical reply within 2 hours', kind: ToastKind.success),
        ),
      ]),
    );
  }
}

// ===========================================================================
// States gallery (design QA)
// ===========================================================================

class StatesGalleryScreen extends StatelessWidget {
  const StatesGalleryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget frame(String title, Widget child, {double h = 360}) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.overline(context)),
            const SizedBox(height: 6),
            AppCard(padding: EdgeInsets.zero, child: SizedBox(height: h, child: child)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text(context.t('States gallery'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        for (final k in EmptyKind.values) frame('EMPTY · ${k.name}', EmptyState(kind: k, actionLabel: 'Action', onAction: () {})),
        for (final k in ErrorKind.values) frame('ERROR · ${k.name}', ErrorState(kind: k, onRetry: () {})),
        frame('SUCCESS', Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const SuccessCheck(), const SizedBox(height: 10), Text(context.t('Evidence uploaded'), style: AppText.h3(context))]))),
        for (final k in SkeletonKind.values) frame('SKELETON · ${k.name}', Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: LoadingSkeleton(kind: k == SkeletonKind.map ? SkeletonKind.detail : k))), h: 300),
      ]),
    );
  }
}
