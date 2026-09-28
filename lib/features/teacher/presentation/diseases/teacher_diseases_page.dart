import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/content_status.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../diseases/diseases_providers.dart';
import '../../../diseases/domain/disease.dart';
import '../widgets/status_chip.dart';

class TeacherDiseasesPage extends ConsumerWidget {
  const TeacherDiseasesPage({super.key});

  Future<void> _setStatus(WidgetRef ref, Disease d, ContentStatus s) async {
    await ref.read(diseaseRemoteProvider).setStatus(d.id, s);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allDiseasesProvider);

    return Scaffold(
      body: AsyncView(
        value: async,
        builder: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No hay enfermedades. Crea la primera.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = list[i];
              return Card(
                child: ListTile(
                  title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    d.shortDescription.isNotEmpty ? d.shortDescription : d.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: StatusChip(status: d.status),
                  onTap: () => context.push('/teacher/diseases/${d.id}'),
                  onLongPress: () => _showActions(context, ref, d),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teacher/diseases/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, Disease d) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/teacher/diseases/${d.id}');
            },
          ),
          if (d.status != ContentStatus.published)
            ListTile(
              leading: const Icon(Icons.publish_outlined),
              title: const Text('Publicar'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, d, ContentStatus.published);
              },
            ),
          if (d.status == ContentStatus.published)
            ListTile(
              leading: const Icon(Icons.unpublished_outlined),
              title: const Text('Pasar a borrador'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, d, ContentStatus.draft);
              },
            ),
          if (d.status != ContentStatus.archived)
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archivar'),
              onTap: () async {
                Navigator.pop(ctx);
                await _setStatus(ref, d, ContentStatus.archived);
              },
            ),
        ]),
      ),
    );
  }
}
