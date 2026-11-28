import 'package:flutter/material.dart';
import '../core/constants/app_assets.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;
  const EmptyStateWidget(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(AppAssets.emptyState, height: 140, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.inbox, size: 80, color: Colors.grey)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ]),
      );
}
