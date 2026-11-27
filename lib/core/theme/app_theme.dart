<<<<<<< HEAD
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

/// Semantic colours that change between light / dark / high-contrast.
@immutable
class UeColors extends ThemeExtension<UeColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color primary;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color error;
  final Color glass;

  const UeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.error,
    required this.glass,
  });

  static const light = UeColors(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    border: AppColors.border,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    textSubtle: AppColors.textSubtle,
    primary: AppColors.navy,
    secondary: AppColors.electric,
    success: AppColors.emerald,
    warning: AppColors.amber,
    error: AppColors.red,
    glass: Color(0xCCFFFFFF),
  );

  static const dark = UeColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    border: AppColors.darkBorder,
    text: AppColors.darkText,
    textMuted: AppColors.darkTextMuted,
    textSubtle: Color(0xFF6E7DA3),
    primary: Color(0xFF7FA3FF),
    secondary: AppColors.electricSoft,
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    glass: Color(0xB30E1830),
  );

  UeColors highContrast(bool dark) => copyWith(
        text: dark ? Colors.white : Colors.black,
        textMuted: dark ? const Color(0xFFDDE5FF) : const Color(0xFF1F2A44),
        textSubtle: dark ? const Color(0xFFC0CBEA) : const Color(0xFF34405C),
        border: dark ? const Color(0xFF8091C0) : const Color(0xFF5B6B8C),
      );

  @override
  UeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? primary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? error,
    Color? glass,
  }) =>
      UeColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        border: border ?? this.border,
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        textSubtle: textSubtle ?? this.textSubtle,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        glass: glass ?? this.glass,
      );

  @override
  UeColors lerp(ThemeExtension<UeColors>? other, double t) {
    if (other is! UeColors) return this;
    return UeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
    );
  }
}

/// Typography scale: H1, H2, H3, Body, Caption, Button, Label.
class AppText {
  AppText._();
  static TextStyle h1(BuildContext c) => Theme.of(c).textTheme.headlineLarge!;
  static TextStyle h2(BuildContext c) => Theme.of(c).textTheme.headlineSmall!;
  static TextStyle h3(BuildContext c) => Theme.of(c).textTheme.titleLarge!;
  static TextStyle title(BuildContext c) => Theme.of(c).textTheme.titleMedium!;
  static TextStyle body(BuildContext c) => Theme.of(c).textTheme.bodyLarge!;
  static TextStyle bodySm(BuildContext c) => Theme.of(c).textTheme.bodyMedium!;
  static TextStyle caption(BuildContext c) => Theme.of(c).textTheme.bodySmall!;
  static TextStyle button(BuildContext c) => Theme.of(c).textTheme.labelLarge!;
  static TextStyle label(BuildContext c) => Theme.of(c).textTheme.labelMedium!;
  static TextStyle overline(BuildContext c) => Theme.of(c).textTheme.labelSmall!;
}

extension ThemeX on BuildContext {
  UeColors get ue => Theme.of(this).extension<UeColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  double get screenWidth => MediaQuery.sizeOf(this).width;
}

class AppTheme {
  AppTheme._();

  static final light = build(dark: false);
  static final darkTheme = build(dark: true);
  static const green = Color(0xFF3BA55D);
  static const blue = Color(0xFF2E7DD1);
=======
import 'package:flutter/material.dart';

class AppTheme {
  // Palette sampled from the UrbanEye logo. Adjust to match Figma tokens.
  static const navy = Color(0xFF14306B);
  static const blue = Color(0xFF2E7DD1);
  static const green = Color(0xFF3BA55D);
  static const bg = Color(0xFFF4F7FB);
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: navy),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
    cardTheme: CardThemeData(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
  );
>>>>>>> origin/yasif-ansari
  static Color statusColor(String s) => switch (s) {
        'Submitted' => Colors.grey,
        'Verified' => blue,
        'Assigned' => Colors.orange,
        'In Progress' => Colors.amber.shade800,
        'Resolved' => green,
        'Rejected' => Colors.red,
        _ => Colors.grey,
      };
<<<<<<< HEAD

  static ThemeData build({required bool dark, bool highContrast = false}) {
    var ue = dark ? UeColors.dark : UeColors.light;
    if (highContrast) ue = ue.highContrast(dark);
    final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    final textTheme = _textTheme(base.textTheme, ue);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.electric,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: dark ? AppColors.electricSoft : AppColors.navy,
      onPrimary: Colors.white,
      secondary: ue.secondary,
      tertiary: ue.success,
      error: ue.error,
      surface: ue.surface,
      onSurface: ue.text,
      outline: ue.border,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: ue.background,
      textTheme: textTheme,
      extensions: [ue],
      appBarTheme: AppBarTheme(
        backgroundColor: ue.background,
        foregroundColor: ue.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: ue.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ue.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyMedium?.copyWith(color: ue.textSubtle),
        labelStyle: textTheme.bodyMedium?.copyWith(color: ue.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: ue.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: ue.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: ue.secondary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: ue.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: ue.error, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: ue.surface,
        selectedColor: ue.secondary.withValues(alpha: 0.14),
        side: BorderSide(color: ue.border),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkSurfaceAlt : AppColors.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ue.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? ue.secondary : null),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static TextTheme _textTheme(TextTheme base, UeColors ue) {
    TextTheme t;
    try {
      t = GoogleFonts.plusJakartaSansTextTheme(base);
    } catch (_) {
      t = base;
    }
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: ue.text, letterSpacing: -1),
      headlineLarge: t.headlineLarge?.copyWith(
          fontSize: 32, fontWeight: FontWeight.w800, color: ue.text, letterSpacing: -0.8, height: 1.15),
      headlineMedium: t.headlineMedium?.copyWith(
          fontSize: 26, fontWeight: FontWeight.w800, color: ue.text, letterSpacing: -0.5, height: 1.2),
      headlineSmall: t.headlineSmall?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w700, color: ue.text, letterSpacing: -0.3, height: 1.25),
      titleLarge: t.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: ue.text),
      titleMedium: t.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: ue.text),
      titleSmall: t.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: ue.text),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 15.5, height: 1.55, color: ue.text),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.5, color: ue.textMuted),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12, height: 1.4, color: ue.textSubtle),
      labelLarge: t.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: t.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ue.text),
      labelSmall: t.labelSmall?.copyWith(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: ue.textSubtle),
    );
  }
=======
>>>>>>> origin/yasif-ansari
}
