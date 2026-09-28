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
final workoutsProvider = StreamProvider<List<Workout>>(
    (ref) => ref.watch(workoutRemoteProvider).watchPublished());

/// Maestros: todos los estados.
final allWorkoutsProvider = StreamProvider<List<Workout>>(
    (ref) => ref.watch(workoutRemoteProvider).watchAll());

/// Entrenamiento del día: UN ejercicio o clase aleatorio de la enfermedad elegida.
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

  // Solo ejercicios/clases con vídeo: sin vídeo no hay forma de completarlos.
  final candidates = <String, DailyPick>{
    for (final e in exercises)
      if (e.diseaseIds.contains(diseaseId) && e.videoId != null)
        'exercise:${e.id}': DailyPick(
          kind: 'exercise',
          id: e.id,
          name: e.name,
          description: e.description,
          durationSeconds: e.durationSeconds,
          videoId: e.videoId!,
        ),
    for (final w in workouts)
      if (w.diseaseIds.contains(diseaseId) && w.videoId != null)
        'workout:${w.id}': DailyPick(
          kind: 'workout',
          id: w.id,
          name: w.name,
          description: w.description,
          durationSeconds: w.durationSeconds,
          videoId: w.videoId!,
        ),
  };
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
