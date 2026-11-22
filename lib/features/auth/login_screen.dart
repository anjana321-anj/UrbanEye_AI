import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../state/auth_controller.dart';
import '../../widgets/ue_widgets.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';
import 'otp_forgot_screen.dart';
import 'staff_login_screen.dart';

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
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue making your city better.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (auth.sessionExpired)
              const Padding(padding: EdgeInsets.only(bottom: 12), child: ErrorBanner('Your session expired. Please sign in again.')),
            ErrorBanner(auth.error),
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
            const SocialButtons(),
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
