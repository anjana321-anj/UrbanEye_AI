import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading, outlined;
  final Color? color;
  const CustomButton({super.key, required this.label, this.onPressed, this.loading = false, this.outlined = false, this.color});
  @override
  Widget build(BuildContext context) {
    final child = loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SizedBox(
      width: double.infinity, height: 50,
      child: outlined
          ? OutlinedButton(onPressed: loading ? null : onPressed, style: OutlinedButton.styleFrom(shape: shape), child: child)
          : FilledButton(onPressed: loading ? null : onPressed, style: FilledButton.styleFrom(shape: shape, backgroundColor: color), child: child),
    );
  }
}
