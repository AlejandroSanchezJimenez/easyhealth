import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers.dart';
import '../../../../shared/models/content_status.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../auth/auth_providers.dart';
import '../../../diseases/diseases_providers.dart';
import '../../../exercises/exercises_providers.dart';
import '../../../videos/domain/video_meta.dart';
import '../../../videos/videos_providers.dart';
import '../../../workouts/domain/workout.dart';
import '../../../workouts/workouts_providers.dart';

class WorkoutFormPage extends ConsumerStatefulWidget {
  const WorkoutFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends ConsumerState<WorkoutFormPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _duration = TextEditingController(text: '0');
  final _difficulty = TextEditingController(text: '1');
  final _thumbnailUrl = TextEditingController();
  final Set<String> _diseaseIds = {};
  final List<WorkoutItem> _items = [];

  String? _videoId;
  String? _videoLabel;
  File? _pendingVideo;
  double _uploadProgress = 0;

  bool _busy = false;
  String? _error;
  Workout? _existing;

  bool get _isNew => widget.id == null || widget.id == 'new';

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    final list = await ref.read(allWorkoutsProvider.future);
    final w = list.where((x) => x.id == widget.id).firstOrNull;
    if (w == null || !mounted) return;

    String? videoLabel;
    if (w.videoId != null) {
      final videos = await ref.read(allVideosProvider.future);
      final v = videos.where((x) => x.id == w.videoId).firstOrNull;
      videoLabel = v?.storagePath.split('/').last ?? w.videoId;
    }

    setState(() {
      _existing = w;
      _name.text = w.name;
      _desc.text = w.description;
      _duration.text = '${w.durationSeconds}';
      _difficulty.text = '${w.difficulty}';
      _thumbnailUrl.text = w.thumbnailUrl ?? '';
      _diseaseIds
        ..clear()
        ..addAll(w.diseaseIds);
      _items
        ..clear()
        ..addAll(w.items);
      _videoId = w.videoId;
      _videoLabel = videoLabel;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _duration.dispose();
    _difficulty.dispose();
    _thumbnailUrl.dispose();
    super.dispose();
  }

  Future<void> _pickExercises() async {
    final exercises = await ref.read(allExercisesProvider.future);
    final usable = exercises.where((e) => e.status != ContentStatus.archived).toList();
    if (!mounted) return;
    if (usable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea ejercicios primero en la pestaña Ejercicios.')),
      );
      return;
    }

    final already = _items.map((e) => e.exerciseId).toSet();
    final selected = <String>{};

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, scroll) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        'Añadir ejercicios',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Añadir (${selected.length})'),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: usable.length,
                    itemBuilder: (_, i) {
                      final e = usable[i];
                      final inClass = already.contains(e.id);
                      final isSel = selected.contains(e.id);
                      return CheckboxListTile(
                        value: inClass || isSel,
                        onChanged: inClass
                            ? null
                            : (v) => setModal(() {
                                  if (v == true) {
                                    selected.add(e.id);
                                  } else {
                                    selected.remove(e.id);
                                  }
                                }),
                        title: Text(e.name),
                        subtitle: Text(
                          '${e.durationSeconds}s · dif. ${e.difficulty}'
                          '${inClass ? ' · ya en la clase' : ''}',
                        ),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        );
      },
    );

    if (ok == true && selected.isNotEmpty) {
      setState(() {
        for (final id in selected) {
          if (!_items.any((x) => x.exerciseId == id)) {
            _items.add(WorkoutItem(exerciseId: id));
          }
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty || result.files.single.path == null) return;
    setState(() {
      _pendingVideo = File(result.files.single.path!);
      _videoLabel = result.files.single.name;
      _error = null;
    });
  }

  Future<String?> _uploadPendingVideo(String uid) async {
    final file = _pendingVideo;
    if (file == null) return _videoId;

    final id = const Uuid().v4();
    final name = _videoLabel ?? 'workout.mp4';
    final path = 'videos/workouts/$id/$name';
    final storageRef = ref.read(storageProvider).ref(path);
    final task = storageRef.putFile(file);
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0 && mounted) {
        setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
      }
    });
    final snap = await task;
    final url = await snap.ref.getDownloadURL();
    final size = await file.length();

    await ref.read(videoRemoteProvider).save(
          VideoMeta(
            id: id,
            storagePath: path,
            downloadUrl: url,
            durationSeconds: int.tryParse(_duration.text) ?? 0,
            fileSize: size,
            status: ContentStatus.published,
          ),
          id: id,
          uid: uid,
        );
    return id;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Añade al menos un ejercicio a la clase.');
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _uploadProgress = 0;
    });
    try {
      final videoId = await _uploadPendingVideo(uid);

      await ref.read(workoutRemoteProvider).save(
            Workout(
              id: _existing?.id ?? '',
              name: name,
              description: _desc.text.trim(),
              durationSeconds: int.tryParse(_duration.text) ?? 0,
              difficulty: int.tryParse(_difficulty.text) ?? 1,
              videoId: videoId,
              thumbnailUrl:
                  _thumbnailUrl.text.trim().isEmpty ? null : _thumbnailUrl.text.trim(),
              items: List.of(_items),
              diseaseIds: _diseaseIds.toList(),
              status: _existing?.status ?? ContentStatus.draft,
            ),
            id: _existing?.id,
            uid: uid,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diseases = ref.watch(allDiseasesProvider);
    final exercises = ref.watch(allExercisesProvider);
    final byId = {
      for (final e in exercises.valueOrNull ?? const []) e.id: e.name,
    };
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nueva clase' : 'Editar clase'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre *'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duración total (seg)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _difficulty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dificultad (1-3)'),
              ),
            ),
          ]),

          // ── Enfermedades ──
          const SizedBox(height: 24),
          Text('Enfermedades asociadas', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Opcional. Filtra para qué enfermedades sirve esta clase.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          AsyncView(
            value: diseases,
            builder: (list) {
              final usable = list.where((d) => d.status != ContentStatus.archived).toList();
              if (usable.isEmpty) return const Text('Crea enfermedades primero.');
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in usable)
                    FilterChip(
                      label: Text(d.name),
                      selected: _diseaseIds.contains(d.id),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _diseaseIds.add(d.id);
                        } else {
                          _diseaseIds.remove(d.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),

          // ── Ejercicios (select) ──
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: Text('Ejercicios de la clase *',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _pickExercises,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Añadir'),
            ),
          ]),
          Text(
            'Elige ejercicios ya creados. Arrastra para reordenar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Aún no hay ejercicios. Pulsa «Añadir» para seleccionarlos.',
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldI, newI) {
                setState(() {
                  if (newI > oldI) newI--;
                  final item = _items.removeAt(oldI);
                  _items.insert(newI, item);
                });
              },
              itemBuilder: (_, i) {
                final item = _items[i];
                return Card(
                  key: ValueKey('${item.exerciseId}-$i'),
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle),
                    title: Text(byId[item.exerciseId] ?? item.exerciseId),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _items.removeAt(i)),
                    ),
                  ),
                );
              },
            ),

          // ── Vídeo de la clase ──
          const SizedBox(height: 24),
          Text('Vídeo de la clase completa', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Opcional. Sube un vídeo de la clase entera. '
            'Si no, la app puede reproducir en secuencia los vídeos de cada ejercicio.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickVideo,
            icon: const Icon(Icons.video_file_outlined),
            label: Text(_videoLabel ?? 'Elegir vídeo de la clase'),
          ),
          if (_videoId != null && _pendingVideo == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.check_circle, size: 18, color: c.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('Vídeo actual: $_videoLabel')),
                TextButton(
                  onPressed: () => setState(() {
                    _videoId = null;
                    _videoLabel = null;
                  }),
                  child: const Text('Quitar'),
                ),
              ]),
            ),
          if (_busy && _uploadProgress > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _uploadProgress),
            Text('${(_uploadProgress * 100).toStringAsFixed(0)} %'),
          ],

          const SizedBox(height: 14),
          TextField(
            controller: _thumbnailUrl,
            decoration: const InputDecoration(labelText: 'URL miniatura (opcional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: c.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_isNew ? 'Crear borrador' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
