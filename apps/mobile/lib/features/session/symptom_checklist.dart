import 'package:flutter/material.dart';
import 'package:nesta_core/nesta_core.dart';

import '../../theme.dart';

/// ACOG egzersizi bırakma belirtileri için işaretleme listesi.
class SymptomChecklist extends StatelessWidget {
  const SymptomChecklist({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final w in warningSigns)
        CheckboxListTile(
          value: selected.contains(w.id),
          onChanged: (v) {
            final next = {...selected};
            v == true ? next.add(w.id) : next.remove(w.id);
            onChanged(next);
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(w.text, style: const TextStyle(fontSize: 15)),
          secondary: w.urgent
              ? const Icon(
                  Icons.emergency_outlined,
                  color: NestaColors.danger,
                  size: 20,
                )
              : null,
        ),
    ],
  );
}
