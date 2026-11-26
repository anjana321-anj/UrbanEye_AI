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
  static Color statusColor(String s) => switch (s) {
        'Submitted' => Colors.grey,
        'Verified' => blue,
        'Assigned' => Colors.orange,
        'In Progress' => Colors.amber.shade800,
        'Resolved' => green,
        'Rejected' => Colors.red,
        _ => Colors.grey,
      };
}
