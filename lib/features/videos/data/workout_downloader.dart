import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/downloads/download_manager.dart';
import '../../exercises/domain/exercise.dart';
import '../../workouts/domain/workout.dart';
import '../domain/video_meta.dart';
import 'offline_library.dart';

/// Descarga una clase completa: vídeos + los datos mínimos para reproducirla sin red.
class WorkoutDownloader {
  WorkoutDownloader(this._dm, this._library);
  final DownloadManager _dm;
  final OfflineLibrary _library;

  /// Tamaño a descargar (para mostrar antes de confirmar).
  int estimateBytes(Workout w, List<Exercise> exercises, Map<String, VideoMeta> videos) =>
      _videoIds(w, exercises).fold(0, (s, id) => s + (videos[id]?.fileSize ?? 0));

  /// ¿Hay versión más nueva en el servidor que la descargada?
  bool isOutdated(Workout w, Map<String, VideoMeta> videos) {
    final off = _library.get(w.id);
    if (off == null) return false;
    if (off.workout.version < w.version) return true;
    return off.videoVersions.entries.any((e) => (videos[e.key]?.version ?? e.value) > e.value);
  }

  Future<void> download({
    required Workout workout,
    required List<Exercise> exercises,
    required Map<String, VideoMeta> videos,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final needed = _videoIds(workout, exercises).map((id) => videos[id]).whereType<VideoMeta>().toList();
    final total = needed.fold<int>(0, (s, v) => s + v.fileSize);
    final previous = _library.get(workout.id);

    var done = 0;
    final paths = <String, String>{};
    final versions = <String, int>{};
    for (final v in needed) {
      final path = '${dir.path}/offline/${v.id}_v${v.version}.mp4';
      if (!await File(path).exists()) {
        await _dm.downloadFile(
          url: v.downloadUrl,
          savePath: path,
          expectedBytes: v.fileSize > 0 ? v.fileSize : null,
          cancelToken: cancelToken,
          onProgress: (r, _) => onProgress?.call(total == 0 ? 0 : (done + r) / total),
        );
      }
      done += v.fileSize;
      paths[v.id] = path;
      versions[v.id] = v.version;
    }

    await _library.save(OfflineWorkout(
      workoutId: workout.id,
      workoutMap: {...workout.toMap(), 'version': workout.version},
      exerciseMaps: {for (final e in exercises) e.id: {...e.toMap(), 'version': e.version}},
      videoPaths: paths,
      videoVersions: versions,
      sizeBytes: total,
      savedAt: DateTime.now(),
    ));

    // Borra versiones antiguas que ya no usa ninguna clase.
    if (previous != null) await _deleteUnused(previous.videoPaths.values);
    onProgress?.call(1);
  }

  Future<void> remove(String workoutId) async {
    final off = _library.get(workoutId);
    await _library.remove(workoutId);
    if (off != null) await _deleteUnused(off.videoPaths.values);
  }

  /// Un vídeo puede compartirse entre clases: solo se borra si nadie lo usa.
  Future<void> _deleteUnused(Iterable<String> candidates) async {
    final inUse = _library.all().values.expand((w) => w.videoPaths.values).toSet();
    for (final p in candidates.where((p) => !inUse.contains(p))) {
      await _dm.deleteFile(p);
    }
  }

  Set<String> _videoIds(Workout w, List<Exercise> ex) =>
      {if (w.videoId != null) w.videoId!, ...ex.map((e) => e.videoId).whereType<String>()};
}
