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
import '../../../exercises/domain/exercise.dart';
import '../../../exercises/exercises_providers.dart';
import '../../../videos/domain/video_meta.dart';
import '../../../videos/videos_providers.dart';

class ExerciseFormPage extends ConsumerStatefulWidget {
  const ExerciseFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<ExerciseFormPage> createState() => _ExerciseFormPageState();
}

class _ExerciseFormPageState extends ConsumerState<ExerciseFormPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _instructions = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _difficulty = TextEditingController(text: '1');
  final _sets = TextEditingController();
  final _reps = TextEditingController();
  final _equipment = TextEditingController();
  final _benefits = TextEditingController();
  final _precautions = TextEditingController();
  final _contraindications = TextEditingController();
  final _diseaseQuery = TextEditingController();
  final Set<String> _diseaseIds = {};

  String? _videoId;
  String? _videoLabel;
  File? _pendingVideo;
  double _uploadProgress = 0;

  bool _busy = false;
  String? _error;
  Exercise? _existing;

  bool get _isNew => widget.id == null || widget.id == 'new';

  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    final list = await ref.read(allExercisesProvider.future);
    final e = list.where((x) => x.id == widget.id).firstOrNull;
    if (e == null || !mounted) return;

    String? videoLabel;
    if (e.videoId != null) {
      final videos = await ref.read(allVideosProvider.future);
      final v = videos.where((x) => x.id == e.videoId).firstOrNull;
      videoLabel = v?.storagePath.split('/').last ?? e.videoId;
    }

    setState(() {
      _existing = e;
      _name.text = e.name;
      _desc.text = e.description;
      _instructions.text = e.instructions.join('\n');
      _duration.text = '${e.durationSeconds}';
      _difficulty.text = '${e.difficulty}';
      _sets.text = e.sets > 0 ? '${e.sets}' : '';
      _reps.text = e.reps > 0 ? '${e.reps}' : '';
      _equipment.text = e.equipment.join('\n');
      _benefits.text = e.benefits.join('\n');
      _precautions.text = e.precautions.join('\n');
      _contraindications.text = e.contraindications.join('\n');
      _diseaseIds
        ..clear()
        ..addAll(e.diseaseIds);
      _videoId = e.videoId;
      _videoLabel = videoLabel;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _instructions.dispose();
    _duration.dispose();
    _difficulty.dispose();
    _sets.dispose();
    _reps.dispose();
    _equipment.dispose();
    _benefits.dispose();
    _precautions.dispose();
    _contraindications.dispose();
    _diseaseQuery.dispose();
    super.dispose();
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
    final name = _videoLabel ?? 'exercise.mp4';
    final path = 'videos/exercises/$id/$name';
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
    if (_diseaseIds.isEmpty) {
      setState(() => _error = 'Selecciona al menos una enfermedad.');
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

      await ref.read(exerciseRemoteProvider).save(
            Exercise(
              id: _existing?.id ?? '',
              name: name,
              description: _desc.text.trim(),
              instructions: _lines(_instructions),
              durationSeconds: int.tryParse(_duration.text) ?? 0,
              difficulty: int.tryParse(_difficulty.text) ?? 1,
              sets: int.tryParse(_sets.text) ?? 0,
              reps: int.tryParse(_reps.text) ?? 0,
              diseaseIds: _diseaseIds.toList(),
              videoId: videoId,
              equipment: _lines(_equipment),
              benefits: _lines(_benefits),
              precautions: _lines(_precautions),
              contraindications: _lines(_contraindications),
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
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nuevo ejercicio' : 'Editar ejercicio'),
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
          TextField(
            controller: _instructions,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Instrucciones (una por línea)',
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duración (seg)'),
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
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _sets,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Series (opcional)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Repeticiones (opcional)'),
              ),
            ),
          ]),

          // ── Enfermedades (multi-select) ──
          const SizedBox(height: 24),
          Text('Enfermedades asociadas *', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Selecciona una o varias. El ejercicio aparecerá en esas enfermedades.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          AsyncView(
            value: diseases,
            builder: (list) {
              if (list.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No hay enfermedades. Crea alguna en la pestaña Enfermedades.',
                      style: TextStyle(color: c.error),
                    ),
                  ),
                );
              }
              final usable = list.where((d) => d.status != ContentStatus.archived).toList();
              final q = _diseaseQuery.text.trim().toLowerCase();
              final filtered =
                  q.isEmpty ? usable : usable.where((d) => d.name.toLowerCase().contains(q)).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _diseaseQuery,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar enfermedad...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(_diseaseQuery.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Ninguna enfermedad coincide con «${_diseaseQuery.text.trim()}».',
                                style: TextStyle(color: c.onSurfaceVariant),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final d in filtered)
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
                            ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Vídeo del ejercicio ──
          const SizedBox(height: 24),
          Text('Vídeo del ejercicio', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Opcional. Se sube a Storage y se vincula a este ejercicio.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickVideo,
            icon: const Icon(Icons.video_file_outlined),
            label: Text(_videoLabel ?? 'Elegir vídeo'),
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
            controller: _equipment,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Equipamiento (uno por línea)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _benefits,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Beneficios (uno por línea)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _precautions,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Precauciones (una por línea)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contraindications,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Contraindicaciones (una por línea)'),
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
