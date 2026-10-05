import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import '../../core/utils/date_key.dart';
import '../../shared/data/content_repository.dart';
import '../auth/auth_providers.dart';
import '../exercises/exercises_providers.dart';
import '../streak/streak_providers.dart';
import 'domain/daily_pick.dart';
import 'domain/daily_workout_generator.dart';
import 'domain/workout.dart';

final workoutRemoteProvider = Provider((ref) => ContentRemote<Workout>(
    ref.watch(firestoreProvider),
    FirestorePaths.workouts,
    Workout.fromMap,
    (w) => w.toMap()));

/// Usuarios: solo publicados.
final workoutsProvider = StreamProvider<List<Workout>>((ref) {
  if (ref.watch(uidProvider) == null) return const Stream.empty();
  return ref.watch(workoutRemoteProvider).watchPublished();
});

/// Maestros: todos los estados.
final allWorkoutsProvider = StreamProvider<List<Workout>>((ref) {
  if (ref.watch(uidProvider) == null) return const Stream.empty();
  return ref.watch(workoutRemoteProvider).watchAll();
});

/// Entrenamiento del día: UNA clase aleatoria de la enfermedad elegida.
/// Si la clase no tiene vídeo propio, se concatenan los vídeos de sus ejercicios.
/// Determinista por (usuario, enfermedad, fecha): no cambia al reconstruir la pantalla.
final dailyPickProvider =
    Provider.family<AsyncValue<DailyPick?>, String>((ref, diseaseId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const AsyncValue.data(null);

  final exercisesAsync = ref.watch(exercisesProvider);
  final workoutsAsync = ref.watch(workoutsProvider);
  final sessionsAsync = ref.watch(sessionsProvider);

  final error = exercisesAsync.error ?? workoutsAsync.error;
  if (error != null) return AsyncValue.error(error, StackTrace.current);

  final exercises = exercisesAsync.valueOrNull;
  final workouts = workoutsAsync.valueOrNull;
  final sessions = sessionsAsync.valueOrNull;
  // Esperar al historial evita que el elegido cambie cuando este termine de cargar.
  if (exercises == null ||
      workouts == null ||
      (sessions == null && !sessionsAsync.hasError)) {
    return const AsyncValue.loading();
  }

  final exercisesById = {for (final e in exercises) e.id: e};

  // Solo clases de la enfermedad. Cada una necesita vídeo propio o, si no tiene,
  // al menos un ejercicio con vídeo: sin vídeo no hay forma de completarla.
  final candidates = <String, DailyPick>{};
  for (final w in workouts) {
    if (!w.diseaseIds.contains(diseaseId)) continue;

    if (w.videoId != null) {
      candidates['workout:${w.id}'] = DailyPick(
        kind: 'workout',
        id: w.id,
        name: w.name,
        description: w.description,
        durationSeconds: w.durationSeconds,
        videoIds: [w.videoId!],
        partNames: [w.name],
      );
      continue;
    }

    // Sin vídeo propio: se encadenan los de sus ejercicios, respetando el orden
    // de la clase. Los ejercicios sin vídeo o inexistentes se omiten.
    final videoIds = <String>[];
    final partNames = <String>[];
    var sumSeconds = 0;
    for (final item in w.items) {
      final e = exercisesById[item.exerciseId];
      if (e == null || e.videoId == null) continue;
      videoIds.add(e.videoId!);
      partNames.add(e.name);
      sumSeconds += e.durationSeconds;
    }
    if (videoIds.isEmpty) continue;

    candidates['workout:${w.id}'] = DailyPick(
      kind: 'workout',
      id: w.id,
      name: w.name,
      description: w.description,
      // Si la clase no declara duración, se usa la suma de sus ejercicios.
      durationSeconds: w.durationSeconds > 0 ? w.durationSeconds : sumSeconds,
      videoIds: videoIds,
      partNames: partNames,
    );
  }
  if (candidates.isEmpty) return const AsyncValue.data(null);

  final today = dateKey(DateTime.now());
  final from = dateKey(DateTime.now()
      .subtract(const Duration(days: AppConfig.recentDaysToAvoid)));
  final recent = (sessions ?? const [])
      .where((s) => s.dateKey.compareTo(from) >= 0 && s.dateKey != today)
      .map((s) => '${s.kind}:${s.refId}')
      .toSet();

  final key = DailyWorkoutGenerator.generate(
    uid: user.uid,
    diseaseId: diseaseId,
    dateKey: today,
    availableIds: candidates.keys.toList(),
    recentIds: recent,
    count: 1,
  ).first;

  return AsyncValue.data(candidates[key]);
});
