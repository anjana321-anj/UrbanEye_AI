import 'package:flutter/material.dart';
import '../core/constants/app_assets.dart';

/// Renders the logo from assets/images/. Swap the file to rebrand; no code change needed.
class AppLogo extends StatelessWidget {
  final double height;
  final bool light;
  const AppLogo({super.key, this.height = 120, this.light = false});
  @override
  Widget build(BuildContext context) => Image.asset(light ? AppAssets.logoLight : AppAssets.logo,
      height: height, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.remove_red_eye, size: height * .6, color: Theme.of(context).colorScheme.primary));
}
