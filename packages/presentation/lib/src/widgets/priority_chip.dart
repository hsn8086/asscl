import 'package:flutter/material.dart';
import 'package:domain/domain.dart';

class PriorityChip extends StatelessWidget {
  final Priority priority;

  const PriorityChip({required this.priority, super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      Priority.high => ('高', Colors.red),
      Priority.medium => ('中', Colors.orange),
      Priority.low => ('低', Colors.green),
    };
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
