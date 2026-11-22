import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../state/auth_controller.dart';
import '../../widgets/ue_widgets.dart';
import 'auth_widgets.dart';

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
    return AuthScaffold(
      showBack: true,
      title: 'Create account',
      subtitle: 'Join thousands of citizens keeping the city clean, safe and smart.',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ErrorBanner(auth.error),
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
            const SocialButtons(),
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
