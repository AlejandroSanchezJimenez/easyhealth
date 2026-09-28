import 'package:flutter/material.dart';

import '../../../../shared/models/content_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final ContentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ContentStatus.draft => ('Borrador', Colors.orange),
      ContentStatus.published => ('Publicado', Colors.green),
      ContentStatus.archived => ('Archivado', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
