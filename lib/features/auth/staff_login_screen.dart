import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/utils.dart';
import '../../state/auth_controller.dart';
import '../../widgets/ue_widgets.dart';
import 'auth_widgets.dart';

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
    return AuthScaffold(
      showBack: true,
      title: 'Municipality Console',
      subtitle: 'Sign in with your municipal staff account. Access is role-based and every action is audit-logged.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ErrorBanner(auth.error),
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
