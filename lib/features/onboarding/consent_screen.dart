import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/env.dart';
import '../../core/di/service_locator.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/utils.dart';
import '../../data/services/device_services.dart';
import '../../state/settings_controller.dart';
import '../../widgets/brand.dart';
import '../../widgets/ue_widgets.dart';

class _PermInfo {
  final AppPermission perm;
  final IconData icon;
  final String title;
  final String why;
  final String usedFor;
  final bool recommended;
  const _PermInfo(this.perm, this.icon, this.title, this.why, this.usedFor, this.recommended);
}

const _perms = [
  _PermInfo(AppPermission.camera, Icons.photo_camera_outlined, 'Camera',
      'Take photos or short videos of the issue as evidence for the municipality.', 'Report evidence · Waste check', true),
  _PermInfo(AppPermission.location, Icons.my_location_rounded, 'Location',
      'Pin the exact place of the issue and show nearby reports, water points and trucks. Only used while the app is open.',
      'Report location · Map · Truck tracking', true),
  _PermInfo(AppPermission.photos, Icons.photo_library_outlined, 'Photos & Videos',
      'Upload evidence you already captured. We only access the items you pick.', 'Upload evidence', true),
  _PermInfo(AppPermission.notifications, Icons.notifications_active_outlined, 'Notifications',
      'Get told when your report is verified, assigned, resolved — or when a pickup truck is near.', 'Status updates', true),
  _PermInfo(AppPermission.microphone, Icons.mic_none_rounded, 'Microphone',
      'Only when you record a video with sound. You can always record without audio.', 'Video evidence (optional)', false),
];

/// Terms, privacy & permission agreement shown before first use.
/// Can be reopened later from Profile → Privacy in review mode.
class ConsentScreen extends StatefulWidget {
  final bool reviewMode;
  const ConsentScreen({super.key, this.reviewMode = false});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final _ps = Services.I.permissions;
  final Map<AppPermission, bool> _selected = {for (final p in _perms) p.perm: p.recommended};
  final Map<AppPermission, PermState?> _state = {};
  bool _terms = false, _privacy = false, _emergency = false, _age = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.reviewMode) {
      _terms = _privacy = _emergency = _age = true;
    }
    _refresh();
  }

  Future<void> _refresh() async {
    for (final p in _perms) {
      final s = await _ps.status(p.perm);
      if (!mounted) return;
      setState(() => _state[p.perm] = s);
    }
  }

  bool get _canContinue => _terms && _privacy && _emergency && _age;

  Future<void> _accept() async {
    setState(() => _busy = true);
    for (final p in _perms) {
      if (_selected[p.perm] == true && _state[p.perm] != PermState.granted) {
        final s = await _ps.request(p.perm);
        if (!mounted) return;
        setState(() => _state[p.perm] = s);
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Haptics.success();
    if (widget.reviewMode) {
      showToast(context, 'Permissions updated', kind: ToastKind.success);
    } else {
      context.read<SettingsController>().acceptConsent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    return Scaffold(
      appBar: widget.reviewMode ? AppBar(title: Text(context.t('Terms, Privacy & Permissions'))) : null,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (!widget.reviewMode) ...[
                  const FadeSlideIn(child: Row(children: [BrandMark(size: 44), SizedBox(width: 12), Wordmark(size: 22)])),
                  const SizedBox(height: 22),
                  FadeSlideIn(
                    index: 1,
                    child: Semantics(header: true, child: Text(context.t('Terms, Privacy & Permissions'), style: AppText.h1(context).copyWith(fontSize: 28))),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 2,
                    child: Text(
                      context.t('Before you start, here is exactly what UrbanEye uses and why. You stay in control — every permission can be changed later in Settings.'),
                      style: AppText.body(context).copyWith(color: ue.textMuted),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                Text(context.t('PERMISSIONS'), style: AppText.overline(context)),
                const SizedBox(height: 10),
                for (var i = 0; i < _perms.length; i++) FadeSlideIn(index: i + 3, child: _permCard(_perms[i])),
                const SizedBox(height: 18),
                Text(context.t('AGREEMENTS'), style: AppText.overline(context)),
                const SizedBox(height: 10),
                _agreement(
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v),
                  title: 'I agree to the Terms of Service',
                  details: const [
                    'Reports must be truthful and about public, municipal issues.',
                    'Do not upload images that identify private individuals unnecessarily (faces, homes interiors).',
                    'False or abusive reports may lead to account suspension.',
                    'Photos you submit may be shared with municipal teams to resolve the issue.',
                    'AI suggestions are advisory; you confirm everything before it is sent.',
                  ],
                ),
                _agreement(
                  value: _privacy,
                  onChanged: (v) => setState(() => _privacy = v),
                  title: 'I agree to the Privacy Policy',
                  details: const [
                    'We collect: name, phone/email, report photos, report location and description.',
                    'Your identity is visible only to authorised staff. You can report anonymously.',
                    'Public dashboards show only aggregated, anonymised statistics.',
                    'Photos are compressed and stripped of metadata (EXIF) before storage.',
                    'Reports are kept for 24 months, then anonymised. You can delete your account anytime.',
                    'We never sell your data or share it for advertising.',
                  ],
                ),
                _agreement(
                  value: _emergency,
                  onChanged: (v) => setState(() => _emergency = v),
                  title: 'I understand UrbanEye is not an emergency service',
                  details: const ['UrbanEye is not an emergency service. In an emergency call 100 (Police), 101 (Fire) or 102 (Ambulance).'],
                  accent: ue.error,
                ),
                _agreement(
                  value: _age,
                  onChanged: (v) => setState(() => _age = v),
                  title: 'I am 16 years or older (or have a guardian\'s consent)',
                  details: const [],
                ),
                const SizedBox(height: 8),
                Text('${context.t('Consent version')} ${Env.consentVersion}', style: AppText.caption(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(color: ue.background, border: Border(top: BorderSide(color: ue.border))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!_canContinue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(context.t('Please accept all agreements to continue.'), style: AppText.caption(context)),
                ),
              UeButton(
                label: widget.reviewMode ? 'Update Permissions' : 'Accept & Continue',
                icon: Icons.verified_user_rounded,
                loading: _busy,
                onPressed: _canContinue ? _accept : null,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _permCard(_PermInfo p) {
    final ue = context.ue;
    final st = _state[p.perm];
    final granted = st == PermState.granted;
    final blocked = st == PermState.permanentlyDenied;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon: p.icon, color: granted ? ue.success : ue.secondary, size: 42, iconSize: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(context.t(p.title), style: AppText.title(context).copyWith(fontSize: 15))),
                const SizedBox(width: 8),
                if (granted)
                  Pill('Allowed', icon: Icons.check_rounded, color: ue.success)
                else if (blocked)
                  Pill('Blocked', icon: Icons.block_rounded, color: ue.error)
                else if (!p.recommended)
                  const Pill('Optional'),
              ]),
              const SizedBox(height: 4),
              Text(context.t(p.why), style: AppText.bodySm(context).copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              Text('${context.t('Used for')}: ${context.t(p.usedFor)}', style: AppText.caption(context)),
              if (blocked)
                TextButton.icon(
                  onPressed: _ps.openSettings,
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: Text(context.t('Open Settings')),
                ),
            ]),
          ),
          Semantics(
            label: '${context.t('Allow')} ${context.t(p.title)}',
            child: Switch(
              value: granted || (_selected[p.perm] ?? false),
              onChanged: granted ? null : (v) => setState(() => _selected[p.perm] = v),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _agreement({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required List<String> details,
    Color? accent,
  }) {
    final ue = context.ue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.only(left: 4, right: 12),
            childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
            leading: Checkbox(
              value: value,
              onChanged: (v) {
                Haptics.tap();
                onChanged(v ?? false);
              },
              activeColor: accent ?? ue.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            title: Text(context.t(title), style: AppText.label(context).copyWith(color: accent ?? ue.text)),
            subtitle: details.isEmpty ? null : Text(context.t('Tap to read summary'), style: AppText.caption(context)),
            trailing: details.isEmpty ? const SizedBox.shrink() : null,
            children: [
              for (final d in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 5, color: ue.textSubtle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.t(d), style: AppText.bodySm(context).copyWith(fontSize: 13))),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
