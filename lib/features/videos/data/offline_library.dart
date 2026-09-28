import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../exercises/domain/exercise.dart';
import '../../workouts/domain/workout.dart';

/// Instantánea mínima de una clase descargada: sus datos, los de sus ejercicios
/// y las rutas de sus vídeos. Es un plan B, no la fuente principal.
class OfflineWorkout {
  const OfflineWorkout({
    required this.workoutId,
    required this.workoutMap,
    required this.exerciseMaps,
    required this.videoPaths,
    required this.videoVersions,
    required this.sizeBytes,
    required this.savedAt,
  });

  final String workoutId;
  final Map<String, dynamic> workoutMap;
  final Map<String, Map<String, dynamic>> exerciseMaps; // exerciseId -> datos
  final Map<String, String> videoPaths; // videoId -> ruta local
  final Map<String, int> videoVersions; // videoId -> versión descargada
  final int sizeBytes;
  final DateTime savedAt;

  Workout get workout => Workout.fromMap(workoutId, workoutMap);
  List<Exercise> get exercises =>
      exerciseMaps.entries.map((e) => Exercise.fromMap(e.key, e.value)).toList();

  Map<String, dynamic> toJson() => {
        'workoutId': workoutId,
        'workoutMap': workoutMap,
        'exerciseMaps': exerciseMaps,
        'videoPaths': videoPaths,
        'videoVersions': videoVersions,
        'sizeBytes': sizeBytes,
        'savedAt': savedAt.toIso8601String(),
      };

  factory OfflineWorkout.fromJson(Map<String, dynamic> m) => OfflineWorkout(
        workoutId: m['workoutId'] as String,
        workoutMap: Map<String, dynamic>.from(m['workoutMap'] as Map),
        exerciseMaps: (m['exerciseMaps'] as Map)
            .map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map))),
        videoPaths: Map<String, String>.from(m['videoPaths'] as Map),
        videoVersions: Map<String, int>.from(m['videoVersions'] as Map),
        sizeBytes: (m['sizeBytes'] as num).toInt(),
        savedAt: DateTime.parse(m['savedAt'] as String),
      );
}

class OfflineLibrary {
  OfflineLibrary(this._p);
  final SharedPreferences _p;
  static const _key = 'offline_workouts';

  Map<String, OfflineWorkout> all() {
    final raw = jsonDecode(_p.getString(_key) ?? '{}') as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, OfflineWorkout.fromJson(Map<String, dynamic>.from(v as Map))));
  }

  OfflineWorkout? get(String workoutId) => all()[workoutId];

  Future<void> save(OfflineWorkout w) {
    final m = all()..[w.workoutId] = w;
    return _write(m);
  }

  Future<void> remove(String workoutId) {
    final m = all()..remove(workoutId);
    return _write(m);
  }

  Future<void> _write(Map<String, OfflineWorkout> m) =>
      _p.setString(_key, jsonEncode(m.map((k, v) => MapEntry(k, v.toJson()))));
}
