import 'package:flutter/material.dart';

class AdminCountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const AdminCountCard({super.key, required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(color: color.withOpacity(.12), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]))),
      );
}
