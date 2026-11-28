import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/settings_controller.dart';

/// Formatting helpers.
class Fmt {
  Fmt._();

  static String relative(DateTime d, {DateTime? now}) {
    now ??= DateTime.now();
    final diff = now.difference(d);
    final sameDay = now.year == d.year && now.month == d.month && now.day == d.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == d.year && yesterday.month == d.month && yesterday.day == d.day;
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60 && diff.inMinutes >= 0) return '${diff.inMinutes} min ago';
    if (sameDay) return 'Today, ${DateFormat('h:mm a').format(d)}';
    if (isYesterday) return 'Yesterday, ${DateFormat('h:mm a').format(d)}';
    if (diff.inDays < 7) return DateFormat('EEE, h:mm a').format(d);
    return DateFormat('d MMM yyyy').format(d);
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String number(num n) => NumberFormat.decimalPattern().format(n);

  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String duration(Duration d) {
    if (d.isNegative) return '-${duration(-d)}';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  /// Masks citizen identity for staff views where full identity isn't needed.
  static String maskName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Citizen';
    final first = parts.first;
    final last = parts.length > 1 ? ' ${parts.last[0]}.' : '';
    return '$first$last';
  }

  static String maskPhone(String phone) {
    if (phone.length < 4) return '••••';
    return '${'•' * (phone.length - 3)}${phone.substring(phone.length - 3)}';
  }
}

/// Input validation shared by every form.
class Validators {
  Validators._();
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?[0-9]{7,15}$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email address';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    return _phone.hasMatch(v.replaceAll(RegExp(r'[\s-]'), '')) ? null : 'Enter a valid phone number';
  }

  static String? phoneOrEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your phone or email';
    final s = v.trim();
    if (_email.hasMatch(s) || _phone.hasMatch(s.replaceAll(RegExp(r'[\s-]'), ''))) return null;
    return 'Enter a valid phone number or email';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
      return 'Include letters and numbers';
    }
    return null;
  }

  static String? vehicle(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    return v.trim().length < 3 ? 'Vehicle number looks too short' : null;
  }

  static String? description(String? v) {
    if (v == null || v.trim().length < 8) return 'Please describe the issue (at least 8 characters)';
    if (v.length > 600) return 'Keep it under 600 characters';
    return null;
  }

  /// Basic sanitisation before sending text to the API.
  static String sanitize(String v) => v.replaceAll(RegExp(r'[<>]'), '').trim();
}

/// Motion & haptics that respect the user's accessibility settings.
class Motion {
  Motion._();

  static bool reduced(BuildContext context) {
    final s = context.read<SettingsController>();
    return s.reducedMotion || MediaQuery.maybeDisableAnimationsOf(context) == true;
  }

  static Duration d(BuildContext context, int ms) =>
      reduced(context) ? Duration.zero : Duration(milliseconds: ms);

  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

class Haptics {
  Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.heavyImpact();
}
