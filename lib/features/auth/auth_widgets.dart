import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../state/auth_controller.dart';
import '../../widgets/brand.dart';
import '../../widgets/ue_widgets.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar(backgroundColor: Colors.transparent) : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                if (!showBack) ...[
                  const FadeSlideIn(child: Center(child: BrandLogo(width: 150))),
                  const SizedBox(height: 18),
                ],
                FadeSlideIn(index: 1, child: Semantics(header: true, child: Text(context.t(title), style: AppText.h1(context)))),
                const SizedBox(height: 8),
                FadeSlideIn(index: 2, child: Text(context.t(subtitle), style: AppText.body(context).copyWith(color: context.ue.textMuted))),
                const SizedBox(height: 28),
                FadeSlideIn(index: 3, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction action;
  final VoidCallback? onSubmit;
  const PasswordField({super.key, required this.controller, this.label = 'Password', this.validator, this.action = TextInputAction.done, this.onSubmit});
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    validator: widget.validator,
    textInputAction: widget.action,
    onFieldSubmitted: (_) => widget.onSubmit?.call(),
    autofillHints: const [AutofillHints.password],
    decoration: InputDecoration(
      labelText: context.t(widget.label),
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    ),
  );
}

class ErrorBanner extends StatelessWidget {
  final String? error;
  const ErrorBanner(this.error, {super.key});
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: Motion.d(context, 250),
    child: error == null
        ? const SizedBox(width: double.infinity)
        : Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.ue.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, color: context.ue.error, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(context.t(error!), style: AppText.bodySm(context).copyWith(color: context.ue.error))),
        ]),
      ),
    ),
  );
}

class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Column(children: [
      Row(children: [
        Expanded(child: Divider(color: context.ue.border)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(context.t('or'), style: AppText.caption(context))),
        Expanded(child: Divider(color: context.ue.border)),
      ]),
      const SizedBox(height: 16),
      UeButton(
        label: 'Continue with Google',
        icon: Icons.g_mobiledata_rounded,
        variant: ButtonVariant.outline,
        onPressed: auth.busy
            ? null
            : () async {
          if (await auth.loginWith('google') && context.mounted) context.popToRoot();
        },
      ),
      const SizedBox(height: 10),
      UeButton(
        label: 'Continue with Apple',
        icon: Icons.apple_rounded,
        variant: ButtonVariant.outline,
        onPressed: auth.busy
            ? null
            : () async {
          if (await auth.loginWith('apple') && context.mounted) context.popToRoot();
        },
      ),
    ]);
  }
}
