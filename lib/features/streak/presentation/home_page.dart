import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors_ext.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_key.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../auth/auth_providers.dart';
import '../../diseases/diseases_providers.dart';
import '../../diseases/selected_disease_provider.dart';
import '../../videos/videos_providers.dart';
import '../../workouts/workouts_providers.dart';
import '../domain/streak_stats.dart';
import '../streak_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? true;

    final display = user?.displayName?.trim() ?? '';
    final name = display.isNotEmpty
        ? display.split(' ').first
        : (user?.email?.split('@').first ?? '');

    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // ── Cabecera ──
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KINEA',
                          style: t.labelMedium?.copyWith(
                              color: c.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6)),
                      const SizedBox(height: 2),
                      Text(name.isEmpty ? 'Hola' : 'Hola, $name',
                          style: t.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: c.primaryContainer,
                foregroundColor: c.onPrimaryContainer,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 20),

            if (!online) ...[
              const _OfflineBanner(),
              const SizedBox(height: 16)
            ],

            const _StreakCard(),
            const SizedBox(height: 20),
            const _DailyCard(),

            // Modo emergencia: solo sin conexión.
            if (!online) ...[
              const SizedBox(height: 20),
              const _DownloadedList()
            ],
          ]),
    );
  }
}

// ───────────────────────── Racha ─────────────────────────
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  static const _letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final stats =
        ref.watch(streakStatsProvider).valueOrNull ?? const StreakStats();
    final active = (ref.watch(sessionsProvider).valueOrNull ?? const [])
        .map((s) => s.dateKey)
        .toSet();

    final today = DateTime.now();
    final week = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final trainedToday = active.contains(dateKey(today));
    final msg = stats.currentStreak == 0
        ? 'Haz un ejercicio hoy y empieza tu racha'
        : trainedToday
            ? '¡Hoy ya has entrenado! Sigue así'
            : '¡Entrena hoy para no perder tu racha!';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: c.primaryContainer, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: c.surface.withAlpha(150), shape: BoxShape.circle),
            child: Icon(Icons.local_fire_department_rounded,
                size: 34, color: context.appColors.streak),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${stats.currentStreak}',
                  style: t.displaySmall?.copyWith(
                      color: c.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              Text(stats.currentStreak == 1 ? 'día de racha' : 'días de racha',
                  style: t.bodyMedium?.copyWith(color: c.onPrimaryContainer)),
            ]),
          ),
          InfoChip(
              label: 'Récord ${stats.longestStreak}',
              icon: Icons.emoji_events_outlined,
              color: c.onSurface),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final d in week)
            Column(children: [
              Text(_letters[d.weekday - 1],
                  style: t.labelMedium?.copyWith(
                      color: c.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _DayDot(
                  done: active.contains(dateKey(d)),
                  isToday: dateKey(d) == dateKey(today)),
            ]),
        ]),
        const SizedBox(height: 14),
        Text(msg,
            style: t.bodyMedium?.copyWith(
                color: c.onPrimaryContainer, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.done, required this.isToday});
  final bool done, isToday;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: done ? c.primary : c.surface.withAlpha(120),
        shape: BoxShape.circle,
        border:
            isToday && !done ? Border.all(color: c.primary, width: 2) : null,
      ),
      child:
          done ? Icon(Icons.check_rounded, size: 20, color: c.onPrimary) : null,
    );
  }
}

// ───────────────────────── Entrenamiento del día ─────────────────────────
class _DailyCard extends ConsumerWidget {
  const _DailyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final diseaseId = ref.watch(selectedDiseaseIdProvider);

    if (diseaseId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Icon(Icons.healing_rounded, size: 40, color: c.primary),
            const SizedBox(height: 10),
            Text('Elige tu enfermedad',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Así podremos prepararte un entrenamiento cada día.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.go('/explore'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('Explorar enfermedades'),
            ),
          ]),
        ),
      );
    }

    final diseaseName = ref
            .watch(diseasesProvider)
            .valueOrNull
            ?.where((d) => d.id == diseaseId)
            .firstOrNull
            ?.name ??
        '';
    final daily = ref.watch(dailyPickProvider(diseaseId));
    final today = dateKey(DateTime.now());
    final doneToday = (ref.watch(sessionsProvider).valueOrNull ?? const [])
        .where((s) => s.dateKey == today)
        .map((s) => '${s.kind}:${s.refId}')
        .toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrenamiento de hoy',
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (diseaseName.isNotEmpty)
                      Text(diseaseName,
                          style: t.bodyMedium
                              ?.copyWith(color: c.onSurfaceVariant)),
                  ]),
            ),
            Icon(Icons.today_rounded, color: c.primary),
          ]),
          const SizedBox(height: 16),
          daily.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('No se pudo cargar: $e'),
            data: (pick) {
              if (pick == null) {
                return Text(
                    'Aún no hay ejercicios ni clases con vídeo para esta enfermedad.',
                    style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant));
              }
              final done = doneToday.contains(pick.key);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      InfoChip(
                          label: pick.isWorkout ? 'Clase' : 'Ejercicio',
                          icon: pick.isWorkout
                              ? Icons.class_outlined
                              : Icons.fitness_center),
                      if (pick.durationSeconds > 0)
                        InfoChip(
                            label: formatMinutes(pick.durationSeconds),
                            icon: Icons.timer_outlined),
                      if (done)
                        InfoChip(
                            label: 'Completado hoy',
                            icon: Icons.check_circle,
                            color: context.appColors.success),
                    ]),
                    const SizedBox(height: 12),
                    Text(pick.name,
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (pick.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(pick.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium
                              ?.copyWith(color: c.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push('/play', extra: pick),
                        icon: Icon(done
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded),
                        label: Text(done ? 'Repetir' : 'Empezar entrenamiento'),
                      ),
                    ),
                  ]);
            },
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Modo emergencia ─────────────────────────
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final warn = context.appColors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn.withAlpha(35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warn.withAlpha(120)),
      ),
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, color: warn),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              'Sin conexión. Tu progreso se guardará y se sincronizará al volver Internet.',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      ]),
    );
  }
}

class _DownloadedList extends ConsumerWidget {
  const _DownloadedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final items = ref.watch(offlineLibraryProvider).all().values.toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Clases descargadas',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Text('No tienes clases descargadas.',
            style: t.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant))
      else
        for (final w in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.download_done_rounded,
                    color: context.appColors.success),
                title: Text(w.workout.name),
                subtitle: Text(
                    '${w.exerciseMaps.length} ejercicios · ${formatBytes(w.sizeBytes)}'),
                // TODO Fase 4: abrir el reproductor con w.videoPaths
              ),
            ),
          ),
    ]);
  }
}
