import 'package:flutter/material.dart';

import '../utils/utils.dart';

/// Premium page transition: fade + subtle upward slide + scale.
Route<T> ueRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, a, sa, child) {
      if (Motion.reduced(context)) return FadeTransition(opacity: a, child: child);
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}

extension NavX on BuildContext {
  Future<T?> push<T>(Widget page) => Navigator.of(this).push<T>(ueRoute<T>(page));
  Future<T?> replace<T>(Widget page) => Navigator.of(this).pushReplacement<T, void>(ueRoute<T>(page));
  void pop<T>([T? result]) => Navigator.of(this).pop<T>(result);
  void popToRoot() => Navigator.of(this).popUntil((r) => r.isFirst);
}
