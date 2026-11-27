import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/services.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: AppLogo(height: 200)));
}

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.block, size: 72, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Access Denied', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Your account cannot open this area (or has been deactivated).', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          CustomButton(label: 'Sign out', onPressed: () => ref.read(authServiceProvider).signOut()),
        ]))),
      );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController(), _otp = TextEditingController(), _email = TextEditingController(), _link = TextEditingController();
  bool _otpSent = false, _busy = false, _adminMode = false, _linkSent = false;
  String? _err;

  Future<void> _send() async {
    setState(() { _busy = true; _err = null; });
    await ref.read(authServiceProvider).sendOtp(_phone.text.trim(),
        onSent: () => setState(() { _otpSent = true; _busy = false; }),
        onError: (e) => setState(() { _err = e; _busy = false; }));
    if (mounted && !_otpSent) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _err = null; });
    final e = await ref.read(authServiceProvider).verifyOtp(_otp.text.trim());
    if (mounted) setState(() { _err = e; _busy = false; });
  }

  Future<void> _adminLink() async {
    if (!AdminService.validEmail(_email.text.trim())) return setState(() => _err = 'Invalid email format');
    final a = ref.read(authServiceProvider);
    try {
      if (!_linkSent) { await a.sendAdminLink(_email.text.trim()); setState(() { _linkSent = true; _err = null; }); }
      else { final e = await a.completeAdminLink(_email.text.trim(), _link.text.trim()); setState(() => _err = e); }
    } catch (e) { setState(() => _err = e.toString()); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
          const AppLogo(height: 180),
          const SizedBox(height: 16),
          if (!_adminMode) ...[
            TextField(controller: _phone, keyboardType: TextInputType.phone, maxLength: 10, enabled: !_otpSent,
                decoration: const InputDecoration(prefixText: '+977 ', labelText: 'Mobile number')),
            if (_otpSent) TextField(controller: _otp, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Enter 6-digit OTP')),
            if (_err != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
            CustomButton(label: _otpSent ? 'Verify OTP' : 'Send OTP', loading: _busy, onPressed: _otpSent ? _verify : _send),
            if (_otpSent) TextButton(onPressed: () => setState(() { _otpSent = false; _otp.clear(); }), child: const Text('Change number / resend')),
          ] else ...[
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email')),
            if (_linkSent) ...[
              const SizedBox(height: 8),
              TextField(controller: _link, decoration: const InputDecoration(labelText: 'Paste sign-in link from email')),
            ],
            if (_err != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            CustomButton(label: _linkSent ? 'Sign in' : 'Email me a login link', onPressed: _adminLink),
          ],
          TextButton(onPressed: () => setState(() { _adminMode = !_adminMode; _err = null; }), child: Text(_adminMode ? 'Citizen / Field worker login' : 'Department Admin login')),
        ])),
      );
}
