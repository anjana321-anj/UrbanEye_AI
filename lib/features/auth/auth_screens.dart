import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../state/auth_controller.dart';
import '../../widgets/brand.dart';
import '../../widgets/ue_widgets.dart';

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  const _AuthScaffold({required this.title, required this.subtitle, required this.child, this.showBack = false});

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

class _ErrorBanner extends StatelessWidget {
  final String? error;
  const _ErrorBanner(this.error);
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

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();
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

// ===========================================================================
// Login
// ===========================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController(text: 'alex.shrestha@example.com');
  final _pw = TextEditingController(text: 'urbaneye123');

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthController>().login(_id.text, _pw.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue making your city better.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (auth.sessionExpired)
              const Padding(padding: EdgeInsets.only(bottom: 12), child: _ErrorBanner('Your session expired. Please sign in again.')),
            _ErrorBanner(auth.error),
            TextFormField(
              controller: _id,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
              validator: Validators.phoneOrEmail,
              decoration: InputDecoration(labelText: context.t('Phone or Email'), prefixIcon: const Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: 14),
            PasswordField(controller: _pw, validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null, onSubmit: _submit),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(const ForgotPasswordScreen()),
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: Text(context.t('Forgot Password?')),
              ),
            ),
            const SizedBox(height: 8),
            UeButton(label: 'Login', loading: auth.busy, onPressed: _submit),
            const SizedBox(height: 22),
            const _SocialButtons(),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(context.t("Don't have an account?"), style: AppText.bodySm(context)),
              TextButton(onPressed: () => context.push(const SignUpScreen()), child: Text(context.t('Sign Up'))),
            ]),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push(const StaffLoginScreen()),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: Text(context.t('Municipality staff? Open Admin Console')),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('Demo: any valid email/phone + password works. Use "fail@test.com" to see the error state.'),
              textAlign: TextAlign.center,
              style: AppText.caption(context),
            ),
          ]),
        ),
      ),
    );
  }
}

// ===========================================================================
// Sign up
// ===========================================================================

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _agree = false;
  bool _showAgreeError = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showAgreeError = !_agree);
    if (!valid || !_agree) return;
    final auth = context.read<AuthController>();
    final ok = await auth.signUp(name: _name.text, phone: _phone.text, email: _email.text, password: _pw.text);
    if (!mounted || !ok) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SuccessCheck(size: 110),
          const SizedBox(height: 12),
          Text(context.t('Account created'), style: AppText.h3(context)),
          const SizedBox(height: 6),
          Text(context.t('Welcome to UrbanEye. Let\'s make the city better together.'), textAlign: TextAlign.center, style: AppText.bodySm(context)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('Continue')))],
      ),
    );
    if (mounted) context.popToRoot();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return _AuthScaffold(
      showBack: true,
      title: 'Create account',
      subtitle: 'Join thousands of citizens keeping the city clean, safe and smart.',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ErrorBanner(auth.error),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (v) => Validators.required(v, 'Full name'),
              decoration: InputDecoration(labelText: context.t('Full Name'), prefixIcon: const Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]'))],
              validator: Validators.phone,
              decoration: InputDecoration(labelText: context.t('Phone'), hintText: '+977 98XXXXXXXX', prefixIcon: const Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              decoration: InputDecoration(labelText: context.t('Email'), prefixIcon: const Icon(Icons.mail_outline_rounded)),
            ),
            const SizedBox(height: 14),
            PasswordField(controller: _pw, validator: Validators.password, action: TextInputAction.next),
            const SizedBox(height: 6),
            ValueListenableBuilder(
              valueListenable: _pw,
              builder: (_, v, __) => _StrengthMeter(password: v.text),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _pw2,
              label: 'Confirm Password',
              validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
              onSubmit: _submit,
            ),
            const SizedBox(height: 14),
            Semantics(
              checked: _agree,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _agree = !_agree;
                  _showAgreeError = false;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(context.t('I agree to the Terms of Service and Privacy Policy, including how my reports and location are used.'),
                            style: AppText.bodySm(context)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            if (_showAgreeError)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(context.t('Please accept the Terms & Privacy Policy'), style: AppText.caption(context).copyWith(color: context.ue.error)),
              ),
            const SizedBox(height: 10),
            UeButton(label: 'Create account', loading: auth.busy, onPressed: _submit),
            const SizedBox(height: 18),
            const _SocialButtons(),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(context.t('Already have an account?'), style: AppText.bodySm(context)),
              TextButton(onPressed: () => context.pop(), child: Text(context.t('Login'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final String password;
  const _StrengthMeter({required this.password});

  @override
  Widget build(BuildContext context) {
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    final labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [context.ue.error, context.ue.error, AppColors.amber, AppColors.electric, AppColors.emerald];
    if (password.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Expanded(child: UeProgressBar(value: (score + 0.5) / 4.5, color: colors[score], height: 5)),
      const SizedBox(width: 10),
      Text(context.t(labels[score]), style: AppText.caption(context).copyWith(color: colors[score], fontWeight: FontWeight.w700)),
    ]);
  }
}

// ===========================================================================
// Forgot password → OTP → reset
// ===========================================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0 destination, 1 otp, 2 new password, 3 done
  final _dest = TextEditingController();
  final _otp = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_dest, _otp, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _resendIn = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _next() async {
    if (_step < 3 && _form.currentState?.validate() == false) return;
    final auth = context.read<AuthController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_step) {
        case 0:
          await auth.sendOtp(_dest.text.trim());
          _startTimer();
          _step = 1;
        case 1:
          final ok = await auth.verifyOtp(_dest.text.trim(), _otp.text);
          if (ok) {
            _step = 2;
          } else {
            _error = 'That code is incorrect. Please try again.';
          }
        case 2:
          await auth.resetPassword(_dest.text.trim(), _pw.text);
          _step = 3;
        default:
          context.pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Forgot password?', 'Verify it\'s you', 'Create new password', 'Password updated'];
    final subs = [
      'Enter the phone number or email linked to your account. We\'ll send a 6-digit code.',
      'Enter the 6-digit code sent to ${_dest.text}. (Demo code: 123456)',
      'Use at least 8 characters with letters and numbers.',
      'You can now sign in with your new password.',
    ];
    return _AuthScaffold(
      showBack: true,
      title: titles[_step],
      subtitle: subs[_step],
      child: Form(
        key: _form,
        child: AnimatedSwitcher(
          duration: Motion.d(context, 300),
          child: Column(
            key: ValueKey(_step),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ErrorBanner(_error),
              if (_step == 0)
                TextFormField(
                  controller: _dest,
                  validator: Validators.phoneOrEmail,
                  decoration: InputDecoration(labelText: context.t('Phone or Email'), prefixIcon: const Icon(Icons.alternate_email_rounded)),
                ),
              if (_step == 1) ...[
                OtpInput(controller: _otp, onCompleted: (_) => _next()),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _resendIn > 0
                        ? null
                        : () async {
                      await context.read<AuthController>().sendOtp(_dest.text.trim());
                      _startTimer();
                      if (mounted) showToast(context, 'A new code was sent', kind: ToastKind.success);
                    },
                    child: Text(_resendIn > 0 ? '${context.t('Resend code in')} ${_resendIn}s' : context.t('Resend code')),
                  ),
                ),
              ],
              if (_step == 2) ...[
                PasswordField(controller: _pw, label: 'New password', validator: Validators.password, action: TextInputAction.next),
                const SizedBox(height: 14),
                PasswordField(controller: _pw2, label: 'Confirm Password', validator: (v) => v != _pw.text ? 'Passwords do not match' : null),
              ],
              if (_step == 3) const Center(child: SuccessCheck(size: 130)),
              const SizedBox(height: 24),
              UeButton(
                label: switch (_step) { 0 => 'Send code', 1 => 'Verify', 2 => 'Reset password', _ => 'Back to Login' },
                loading: _busy,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six-box OTP input with auto-advance and paste support.
class OtpInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final int length;
  const OtpInput({super.key, required this.controller, required this.onCompleted, this.length = 6});
  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _changed() {
    setState(() {});
    if (widget.controller.text.length == widget.length) widget.onCompleted(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ue = context.ue;
    final text = widget.controller.text;
    return Semantics(
      label: 'One-time code, ${widget.length} digits',
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (i) {
              final filled = i < text.length;
              final active = i == text.length;
              return AnimatedContainer(
                duration: Motion.d(context, 180),
                width: 48,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ue.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: active ? ue.secondary : (filled ? ue.text.withValues(alpha: 0.3) : ue.border), width: active ? 2 : 1.2),
                ),
                child: AnimatedScale(
                  scale: filled ? 1 : 0.5,
                  duration: Motion.d(context, 160),
                  child: Text(filled ? text[i] : '', style: AppText.h2(context)),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

// ===========================================================================
// Staff login (admin console)
// ===========================================================================

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'sita.maharjan@kathmandu.gov.np');
  final _pw = TextEditingController(text: 'admin12345');

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await context.read<AuthController>().loginStaff(_email.text, _pw.text);
    if (ok && mounted) context.popToRoot();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return _AuthScaffold(
      showBack: true,
      title: 'Municipality Console',
      subtitle: 'Sign in with your municipal staff account. Access is role-based and every action is audit-logged.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _ErrorBanner(auth.error),
          TextFormField(
            controller: _email,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.t('Staff email'), prefixIcon: const Icon(Icons.badge_outlined)),
          ),
          const SizedBox(height: 14),
          PasswordField(controller: _pw, validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null, onSubmit: _submit),
          const SizedBox(height: 20),
          UeButton(label: 'Sign in to Console', icon: Icons.admin_panel_settings_rounded, loading: auth.busy, onPressed: _submit),
          const SizedBox(height: 14),
          AppCard(
            color: context.ue.surfaceAlt,
            bordered: false,
            child: Row(children: [
              Icon(Icons.shield_outlined, color: context.ue.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t('Demo accounts: sita.maharjan@kathmandu.gov.np (Admin), hari@kathmandu.gov.np (Operator), manisha@kathmandu.gov.np (Supervisor), dipak@kathmandu.gov.np (Team Member).'),
                  style: AppText.caption(context),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
