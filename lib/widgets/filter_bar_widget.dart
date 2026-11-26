import 'package:flutter/material.dart';

/// Generic dropdown filter row. Pass only the filters a screen needs.
class FilterBarWidget extends StatelessWidget {
  final Map<String, List<String>> options; // label -> choices
  final Map<String, String?> values;
  final void Function(String label, String? value) onChanged;
  const FilterBarWidget({super.key, required this.options, required this.values, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
          for (final e in options.entries)
            Padding(padding: const EdgeInsets.only(right: 8), child: DropdownButton<String?>(
              value: values[e.key], hint: Text(e.key), underline: const SizedBox(),
              items: [DropdownMenuItem(value: null, child: Text('All ${e.key}')), for (final c in e.value) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => onChanged(e.key, v),
            )),
        ]),
      );
}
