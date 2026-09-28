import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/content_status.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../diseases/diseases_providers.dart';
import '../../../exercises/domain/exercise.dart';
import '../../../exercises/exercises_providers.dart';
import '../widgets/status_chip.dart';

class TeacherExercisesPage extends ConsumerWidget {
  const TeacherExercisesPage({super.key});

  Future<void> _setStatus(WidgetRef ref, Exercise e, ContentStatus s) async {
    await ref.read(exerciseRemoteProvider).setStatus(e.id, s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allExercisesProvider);
    final diseases = ref.watch(allDiseasesProvider).valueOrNull ?? const [];
    final diseaseName = {for (final d in diseases) d.id: d.name};

    return Scaffold(
      body: AsyncView(
        value: async,
        builder: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No hay ejercicios. Crea el primero.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = list[i];
              final enf = e.diseaseIds
                  .map((id) => diseaseName[id] ?? id)
                  .join(', ');
              return Card(
                child: ListTile(
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      if (enf.isNotEmpty) enf,
                      '${e.durationSeconds}s · dif. ${e.difficulty}',
                      if (e.videoId != null) '🎬 vídeo',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: StatusChip(status: e.status),
                  onTap: () => context.push('/teacher/exercises/${e.id}'),
                  onLongPress: () => _showActions(context, ref, e),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/exercises/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, Exercise e) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/teacher/exercises/${e.id}');
            },
          ),
          if (e.status != ContentStatus.published)
            ListTile(
              leading: const Icon(Icons.publish_outlined),
              title: const Text('Publicar'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, e, ContentStatus.published);
              },
            ),
          if (e.status == ContentStatus.published)
            ListTile(
              leading: const Icon(Icons.unpublished_outlined),
              title: const Text('Pasar a borrador'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, e, ContentStatus.draft);
              },
            ),
          if (e.status != ContentStatus.archived)
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archivar'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, e, ContentStatus.archived);
              },
            ),
        ]),
      ),
    );
  }
}
