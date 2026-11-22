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
import '../../widgets/ue_widgets.dart';
import 'auth_widgets.dart';

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
    return AuthScaffold(
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
              ErrorBanner(_error),
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
