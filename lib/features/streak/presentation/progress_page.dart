import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors_ext.dart';
import '../../../core/utils/date_key.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../exercises/exercises_providers.dart';
import '../../workouts/workouts_providers.dart';
import '../domain/session_record.dart';
import '../domain/streak_stats.dart';
import '../streak_providers.dart';

const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre'
];

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});
  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stats =
        ref.watch(streakStatsProvider).valueOrNull ?? const StreakStats();
    final sessions = [
      ...(ref.watch(sessionsProvider).valueOrNull ?? const <SessionRecord>[])
    ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Tu progreso',
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  color: context.appColors.streak,
                  value: '${stats.currentStreak}',
                  label: 'Racha actual',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_rounded,
                  color: context.appColors.warning,
                  value: '${stats.longestStreak}',
                  label: 'Mejor racha',
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  value: '${stats.totalExerciseDays}',
                  label: 'Días activos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  value: formatMinutes(stats.totalExerciseSeconds),
                  label: 'Tiempo total',
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _calendar(sessions),
            const SizedBox(height: 20),
            Text('Historial',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _history(sessions.take(8).toList()),
          ]),
    );
  }

  // ───────────── Calendario mensual ─────────────
  Widget _calendar(List<SessionRecord> sessions) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final active = sessions.map((s) => s.dateKey).toSet();
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final blanks =
        DateTime(_month.year, _month.month, 1).weekday - 1; // lunes = 0
    final activeThisMonth = List.generate(
            daysInMonth, (i) => DateTime(_month.year, _month.month, i + 1))
        .where((d) => active.contains(dateKey(d)))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
              child: Column(children: [
                Text('${_months[_month.month - 1]} ${_month.year}',
                    style:
                        t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                InfoChip(
                    label: '$activeThisMonth días activos',
                    icon: Icons.check_circle_outline,
                    color: c.primary),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrent
                  ? null
                  : () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            for (final l in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Text(l,
                      style: t.labelMedium?.copyWith(
                          color: c.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _CalendarDay(
                  day: d,
                  done: active.contains(
                      dateKey(DateTime(_month.year, _month.month, d))),
                  isToday: isCurrent && d == now.day,
                ),
            ],
          ),
        ]),
      ),
    );
  }

  // ───────────── Historial ─────────────
  Widget _history(List<SessionRecord> list) {
    final c = Theme.of(context).colorScheme;
    if (list.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text('Todavía no has completado ningún ejercicio.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.onSurfaceVariant)),
          ),
        ),
      );
    }
    final names = {
      for (final e in ref.watch(exercisesProvider).valueOrNull ?? const [])
        e.id: e.name,
      for (final w in ref.watch(workoutsProvider).valueOrNull ?? const [])
        w.id: w.name,
    };
    IconData iconFor(String k) => switch (k) {
          'workout' => Icons.class_rounded,
          'daily' => Icons.today_rounded,
          _ => Icons.fitness_center,
        };
    String fallback(String k) => switch (k) {
          'workout' => 'Clase',
          'daily' => 'Entrenamiento diario',
          _ => 'Ejercicio',
        };
    String fmt(DateTime d) {
      final l = d.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(l.day)}/${two(l.month)} · ${two(l.hour)}:${two(l.minute)}';
    }

    return Card(
      child: Column(children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) Divider(height: 1, color: c.outlineVariant),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: c.primaryContainer,
              foregroundColor: c.onPrimaryContainer,
              child: Icon(iconFor(list[i].kind), size: 20),
            ),
            title: Text(names[list[i].refId] ?? fallback(list[i].kind)),
            subtitle: Text(fmt(list[i].completedAt)),
            trailing: Text(formatMinutes(list[i].seconds),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withAlpha(40), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          Text(label,
              style: t.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay(
      {required this.day, required this.done, required this.isToday});
  final int day;
  final bool done, isToday;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? c.primary : null,
        shape: BoxShape.circle,
        border:
            isToday && !done ? Border.all(color: c.primary, width: 2) : null,
      ),
      child: Text('$day',
          style: TextStyle(
            color: done ? c.onPrimary : c.onSurface,
            fontWeight: done || isToday ? FontWeight.w800 : FontWeight.w500,
          )),
    );
  }
}
