import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/content_status.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../workouts/domain/workout.dart';
import '../../../workouts/workouts_providers.dart';
import '../widgets/status_chip.dart';

class TeacherWorkoutsPage extends ConsumerWidget {
  const TeacherWorkoutsPage({super.key});

  Future<void> _setStatus(WidgetRef ref, Workout w, ContentStatus s) async {
    await ref.read(workoutRemoteProvider).setStatus(w.id, s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allWorkoutsProvider);

    return Scaffold(
      body: AsyncView(
        value: async,
        builder: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No hay clases. Crea la primera.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final w = list[i];
              return Card(
                child: ListTile(
                  title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${w.items.length} ejercicios · ${w.durationSeconds}s · dif. ${w.difficulty}',
                  ),
                  trailing: StatusChip(status: w.status),
                  onTap: () => context.push('/teacher/workouts/${w.id}'),
                  onLongPress: () => _showActions(context, ref, w),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/workouts/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, Workout w) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/teacher/workouts/${w.id}');
            },
          ),
          if (w.status != ContentStatus.published)
            ListTile(
              leading: const Icon(Icons.publish_outlined),
              title: const Text('Publicar'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, w, ContentStatus.published);
              },
            ),
          if (w.status == ContentStatus.published)
            ListTile(
              leading: const Icon(Icons.unpublished_outlined),
              title: const Text('Pasar a borrador'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, w, ContentStatus.draft);
              },
            ),
          if (w.status != ContentStatus.archived)
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archivar'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, w, ContentStatus.archived);
              },
            ),
        ]),
      ),
    );
  }
}
