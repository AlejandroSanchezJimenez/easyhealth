import '../../../shared/widgets/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors_ext.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/exercises_providers.dart';
import '../../videos/videos_providers.dart';
import '../../workouts/domain/workout.dart';
import '../../workouts/workouts_providers.dart';
import '../diseases_providers.dart';
import '../domain/disease.dart';
import '../selected_disease_provider.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});
  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  String _q = '';
  bool _onlyMine = true;

  bool _match(String s) =>
      _q.isEmpty || s.toLowerCase().contains(_q.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Explorar',
                  style:
                      t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                    hintText: 'Buscar enfermedades, ejercicios o clases',
                    prefixIcon: Icon(Icons.search)),
              ),
            ]),
          ),
          const TabBar(tabs: [
            Tab(text: 'Enfermedades'),
            Tab(text: 'Ejercicios'),
            Tab(text: 'Clases')
          ]),
          Expanded(
              child: TabBarView(
                  children: [_diseasesTab(), _exercisesTab(), _workoutsTab()])),
        ]),
      ),
    );
  }

  // ───────────── Enfermedades ─────────────
  Widget _diseasesTab() {
    final exercises =
        ref.watch(exercisesProvider).valueOrNull ?? const <Exercise>[];
    final workouts =
        ref.watch(workoutsProvider).valueOrNull ?? const <Workout>[];
    final selected = ref.watch(selectedDiseaseIdProvider);

    return AsyncView(
      value: ref.watch(diseasesProvider),
      builder: (list) {
        final items = list
            .where((d) =>
                _match(d.name) ||
                _match(d.shortDescription) ||
                _match(d.category ?? ''))
            .toList();
        if (items.isEmpty) {
          return const _Empty(
              icon: Icons.healing_outlined,
              text: 'No hay enfermedades disponibles');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = items[i];
            final nEx =
                exercises.where((e) => e.diseaseIds.contains(d.id)).length;
            final nWo =
                workouts.where((w) => w.diseaseIds.contains(d.id)).length;
            final isSel = d.id == selected;
            return _ContentCard(
              highlighted: isSel,
              leading: _Thumb(url: d.imageUrl, icon: Icons.healing_rounded),
              title: d.name,
              subtitle: d.shortDescription,
              chips: [
                if (isSel)
                  InfoChip(
                      label: 'Seleccionada',
                      icon: Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary),
                InfoChip(label: '$nEx ejercicios', icon: Icons.fitness_center),
                InfoChip(label: '$nWo clases', icon: Icons.class_outlined),
              ],
              onTap: () => _showDisease(d, nEx, nWo, isSel),
            );
          },
        );
      },
    );
  }

  void _showDisease(Disease d, int nEx, int nWo, bool isSel) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    _sheet(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(d.name,
          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (d.category != null)
          InfoChip(label: d.category!, icon: Icons.label_outline),
        InfoChip(label: '$nEx ejercicios', icon: Icons.fitness_center),
        InfoChip(label: '$nWo clases', icon: Icons.class_outlined),
      ]),
      const SizedBox(height: 16),
      Text(d.description.isNotEmpty ? d.description : d.shortDescription,
          style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: isSel
            ? null
            : () {
                ref.read(selectedDiseaseIdProvider.notifier).select(d.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ahora entrenas para: ${d.name}')));
              },
        child: Text(isSel ? 'Enfermedad seleccionada' : 'Usar esta enfermedad'),
      ),
    ]));
  }

  // ───────────── Ejercicios ─────────────
  Widget _exercisesTab() {
    final sel = ref.watch(selectedDiseaseIdProvider);
    return Column(children: [
      _filterRow(sel),
      Expanded(
        child: AsyncView(
          value: ref.watch(exercisesProvider),
          builder: (list) {
            final items = list
                .where((e) => _match(e.name) || _match(e.description))
                .where((e) =>
                    !_onlyMine || sel == null || e.diseaseIds.contains(sel))
                .toList();
            if (items.isEmpty) {
              return const _Empty(
                  icon: Icons.fitness_center,
                  text: 'No hay ejercicios disponibles');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final e = items[i];
                return _ContentCard(
                  leading:
                      _Thumb(url: e.thumbnailUrl, icon: Icons.fitness_center),
                  title: e.name,
                  subtitle: e.description,
                  chips: [
                    if (e.durationSeconds > 0)
                      InfoChip(
                          label: formatMinutes(e.durationSeconds),
                          icon: Icons.timer_outlined),
                    InfoChip(
                        label: difficultyLabel(e.difficulty),
                        icon: Icons.bar_chart_rounded),
                    if (e.videoId != null)
                      const InfoChip(
                          label: 'Vídeo', icon: Icons.play_circle_outline),
                  ],
                  onTap: () => _showExercise(e),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  void _showExercise(Exercise e) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final warn = context.appColors.warning;
    _sheet(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name,
          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (e.durationSeconds > 0)
          InfoChip(
              label: formatMinutes(e.durationSeconds),
              icon: Icons.timer_outlined),
        InfoChip(
            label: difficultyLabel(e.difficulty),
            icon: Icons.bar_chart_rounded),
        for (final eq in e.equipment)
          InfoChip(label: eq, icon: Icons.sports_gymnastics),
      ]),
      if (e.videoId != null) ...[
        const SizedBox(height: 16),
        _VideoSection(videoId: e.videoId!),
      ],
      if (e.description.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(e.description,
            style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
      ],
      _Bullets(title: 'Beneficios', items: e.benefits),
      _Bullets(title: 'Instrucciones', items: e.instructions, numbered: true),
      if (e.precautions.isNotEmpty || e.contraindications.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: warn.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: warn.withAlpha(120)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: warn),
              const SizedBox(width: 8),
              Text('Seguridad',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            _Bullets(title: 'Precauciones', items: e.precautions, top: 10),
            _Bullets(
                title: 'Contraindicaciones',
                items: e.contraindications,
                top: 10),
          ]),
        ),
      const SizedBox(height: 16),
      Text(
          'Información orientativa. Consulta con tu profesional sanitario antes de empezar.',
          style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
    ]));
  }

  // ───────────── Clases ─────────────
  Widget _workoutsTab() {
    final sel = ref.watch(selectedDiseaseIdProvider);
    final downloaded = ref.watch(offlineLibraryProvider).all();
    return Column(children: [
      _filterRow(sel),
      Expanded(
        child: AsyncView(
          value: ref.watch(workoutsProvider),
          builder: (list) {
            final items = list
                .where((w) => _match(w.name) || _match(w.description))
                .where((w) =>
                    !_onlyMine || sel == null || w.diseaseIds.contains(sel))
                .toList();
            if (items.isEmpty) {
              return const _Empty(
                  icon: Icons.class_outlined,
                  text: 'No hay clases disponibles');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final w = items[i];
                return _ContentCard(
                  leading:
                      _Thumb(url: w.thumbnailUrl, icon: Icons.class_rounded),
                  title: w.name,
                  subtitle: w.description,
                  chips: [
                    if (w.durationSeconds > 0)
                      InfoChip(
                          label: formatMinutes(w.durationSeconds),
                          icon: Icons.timer_outlined),
                    InfoChip(
                        label: difficultyLabel(w.difficulty),
                        icon: Icons.bar_chart_rounded),
                    InfoChip(
                        label: '${w.items.length} ejercicios',
                        icon: Icons.fitness_center),
                    if (downloaded.containsKey(w.id))
                      InfoChip(
                          label: 'Descargada',
                          icon: Icons.download_done_rounded,
                          color: context.appColors.success),
                  ],
                  onTap: () => _showWorkout(w),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  void _showWorkout(Workout w) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final warn = context.appColors.warning;
    final byId = {
      for (final e
          in ref.read(exercisesProvider).valueOrNull ?? const <Exercise>[])
        e.id: e
    };

    _sheet(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Cabecera de la clase ──
      Text(w.name,
          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (w.durationSeconds > 0)
          InfoChip(
              label: formatMinutes(w.durationSeconds),
              icon: Icons.timer_outlined),
        InfoChip(
            label: difficultyLabel(w.difficulty),
            icon: Icons.bar_chart_rounded),
        InfoChip(
            label: '${w.items.length} ejercicios', icon: Icons.fitness_center),
      ]),
      if (w.videoId != null) ...[
        const SizedBox(height: 16),
        _VideoSection(videoId: w.videoId!),
      ],
      if (w.description.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(w.description,
            style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
      ],

      // ── Lista de ejercicios (colapsables) ──
      const SizedBox(height: 24),
      Text('Ejercicios de la clase',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),

      for (var i = 0; i < w.items.length; i++) ...[
        Builder(builder: (_) {
          final item = w.items[i];
          final e = byId[item.exerciseId];

          if (e == null) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: c.primaryContainer,
                foregroundColor: c.onPrimaryContainer,
                child: Text('${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: const Text('Ejercicio'),
              subtitle: Text([
                if (item.seconds != null) formatMinutes(item.seconds!),
                if (item.reps != null) '${item.reps} repeticiones',
              ].join(' · ')),
            );
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: c.primaryContainer,
                foregroundColor: c.onPrimaryContainer,
                child: Text('${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(e.name,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              subtitle: Text([
                if (item.seconds != null) formatMinutes(item.seconds!),
                if (item.reps != null) '${item.reps} repeticiones',
                if (item.seconds == null && e.durationSeconds > 0)
                  formatMinutes(e.durationSeconds),
                difficultyLabel(e.difficulty),
              ].where((s) => s.isNotEmpty).join(' · ')),
              children: [
                // Chips de equipo
                if (e.equipment.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final eq in e.equipment)
                        InfoChip(label: eq, icon: Icons.sports_gymnastics),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Vídeo
                if (e.videoId != null) ...[
                  _VideoSection(videoId: e.videoId!, maxHeight: 200),
                  const SizedBox(height: 12),
                ],

                // Descripción
                if (e.description.isNotEmpty) ...[
                  Text(e.description,
                      style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(height: 8),
                ],

                _Bullets(title: 'Beneficios', items: e.benefits, top: 8),
                _Bullets(
                    title: 'Instrucciones',
                    items: e.instructions,
                    numbered: true,
                    top: 8),

                if (e.precautions.isNotEmpty || e.contraindications.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: warn.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: warn.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.warning_amber_rounded,
                              color: warn, size: 20),
                          const SizedBox(width: 8),
                          Text('Seguridad',
                              style: t.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                        _Bullets(
                            title: 'Precauciones',
                            items: e.precautions,
                            top: 8),
                        _Bullets(
                            title: 'Contraindicaciones',
                            items: e.contraindications,
                            top: 8),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],

      const SizedBox(height: 24),
      Text(
        'Información orientativa. Consulta con tu profesional sanitario antes de empezar.',
        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
      ),
      // const SizedBox(height: 16),
      // FilledButton.icon(
      //   onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(
      //           content: Text('Descargas y reproductor: siguientes fases.'))),
      //   icon: const Icon(Icons.download_rounded),
      //   label: const Text('Descargar para usar sin conexión'),
      // ),
    ]));
  }

  // ───────────── Utilidades ─────────────
  Widget _filterRow(String? sel) {
    if (sel == null) return const SizedBox.shrink();
    final name = ref
            .watch(diseasesProvider)
            .valueOrNull
            ?.where((d) => d.id == sel)
            .firstOrNull
            ?.name ??
        'mi enfermedad';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          label: Text('Solo para $name'),
          selected: _onlyMine,
          onSelected: (v) => setState(() => _onlyMine = v),
        ),
      ),
    );
  }

  void _sheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, // empieza un poco más bajo
          minChildSize: 0.45, // se puede arrastrar hasta aquí
          maxChildSize: 0.95, // nunca más del 95 %
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController, // ← importante: el mismo controller
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: child,
            );
          },
        );
      },
    );
  }
}

// ───────────── Widgets de apoyo ─────────────
class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.onTap,
    this.highlighted = false,
  });
  final Widget leading;
  final String title, subtitle;
  final List<Widget> chips;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: c.primary, width: 2))
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ],
                  ]),
            ),
            Icon(Icons.chevron_right, color: c.outline),
          ]),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url, required this.icon});
  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget fallback() => Container(
        color: c.primaryContainer,
        child: Icon(icon, size: 28, color: c.onPrimaryContainer));
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: (url == null || url!.isEmpty)
            ? fallback()
            : Image.network(url!,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback()),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(
      {required this.title,
      required this.items,
      this.numbered = false,
      this.top = 20});
  final String title;
  final List<String> items;
  final bool numbered;
  final double top;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 22,
                  child: Text(numbered ? '${i + 1}.' : '•',
                      style: TextStyle(
                          color: c.primary, fontWeight: FontWeight.w800))),
              Expanded(child: Text(items[i], style: t.bodyMedium)),
            ]),
          ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: c.outline),
        const SizedBox(height: 10),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: c.onSurfaceVariant)),
      ]),
    );
  }
}

class _VideoSection extends ConsumerWidget {
  const _VideoSection({
    required this.videoId,
    this.maxHeight = 220, // ← nuevo
  });
  final String videoId;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(videosProvider).isLoading;
    final video = ref.watch(videoByIdProvider(videoId));

    if (video == null) {
      return loading
          ? const _VideoPlaceholder(loading: true)
          : const _VideoPlaceholder(text: 'Vídeo no disponible');
    }
    if (video.downloadUrl.trim().isEmpty) {
      return const _VideoPlaceholder(text: 'El vídeo no tiene una URL válida');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: AppVideoPlayer(
            key: ValueKey(video.downloadUrl),
            url: video.downloadUrl,
            forceAspectRatio: 16 / 9, // ← nuevo parámetro
          ),
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({this.text, this.loading = false});
  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: loading
          ? const CircularProgressIndicator()
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_off_outlined, color: c.outline, size: 36),
              const SizedBox(height: 8),
              Text(text ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.onSurfaceVariant)),
            ]),
    );
  }
}
