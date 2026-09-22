import 'package:flutter/material.dart';

/// A small pill showing a status with a semantic colour. Used for session
/// open/closed, attendance present/absent, account active/disabled, etc.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Green "active/open/present" style.
  factory StatusChip.positive(String label, {IconData? icon}) =>
      StatusChip(label: label, color: const Color(0xFF2E7D32), icon: icon);

  /// Grey "closed/inactive/ended" style.
  factory StatusChip.neutral(String label, {IconData? icon}) =>
      StatusChip(label: label, color: const Color(0xFF6B7280), icon: icon);

  /// Amber "warning/pending" style.
  factory StatusChip.warning(String label, {IconData? icon}) =>
      StatusChip(label: label, color: const Color(0xFFB26A00), icon: icon);

  /// Red "error/absent/disabled" style.
  factory StatusChip.negative(String label, {IconData? icon}) =>
      StatusChip(label: label, color: const Color(0xFFC62828), icon: icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
