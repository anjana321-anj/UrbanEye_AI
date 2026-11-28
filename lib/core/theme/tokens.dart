import 'package:flutter/material.dart';

/// UrbanEye design tokens. Every colour, radius, spacing and shadow used in
/// the product comes from here so the system stays consistent.
class AppColors {
  AppColors._();

  // Brand
  static const navy = Color(0xFF0B1B3F); // Primary — midnight
  static const navy700 = Color(0xFF132A5C);
  static const navy500 = Color(0xFF1F3F86);
  static const electric = Color(0xFF2F6BFF); // Secondary
  static const electricSoft = Color(0xFF5B8CFF);
  static const sky = Color(0xFF38BDF8);
  static const emerald = Color(0xFF10B981); // Accent / success
  static const amber = Color(0xFFF59E0B); // Warning / pending
  static const red = Color(0xFFEF4444); // Error / critical
  static const violet = Color(0xFF8B5CF6);
  static const teal = Color(0xFF14B8A6);

  // Light neutrals
  static const background = Color(0xFFF5F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEEF2F9);
  static const border = Color(0xFFE3E8F2);
  static const text = Color(0xFF0B1B3F);
  static const textMuted = Color(0xFF5B6B8C);
  static const textSubtle = Color(0xFF8A97B3);

  // Dark neutrals
  static const darkBackground = Color(0xFF060C1A);
  static const darkSurface = Color(0xFF0E1830);
  static const darkSurfaceAlt = Color(0xFF15223F);
  static const darkBorder = Color(0xFF22325A);
  static const darkText = Color(0xFFEAF0FF);
  static const darkTextMuted = Color(0xFF9DAACB);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navy500, electric],
  );

  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2F6BFF), Color(0xFF0B1B3F)],
  );
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const page = 20.0;
}

class AppRadii {
  AppRadii._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
  static BorderRadius get card => BorderRadius.circular(lg);
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> soft(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return const [];
    return [
      BoxShadow(
        color: AppColors.navy.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: AppColors.navy.withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> glow(Color c) => [
        BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
      ];
}

/// Breakpoints used by responsive layouts.
class Breakpoints {
  Breakpoints._();
  static const mobile = 600.0;
  static const tablet = 900.0;
  static const desktop = 1200.0;
}
