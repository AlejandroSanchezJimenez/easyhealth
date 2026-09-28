import 'package:flutter/material.dart';

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = color ?? c.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4)
        ],
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Formatos compartidos ──
String difficultyLabel(int d) =>
    switch (d) { <= 1 => 'Fácil', 2 => 'Media', _ => 'Difícil' };

String formatMinutes(int seconds) {
  final m = (seconds / 60).round();
  return m < 1 ? '<1 min' : '$m min';
}

String formatBytes(int b) {
  if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(0)} MB';
  return '${(b / 1073741824).toStringAsFixed(1)} GB';
}
