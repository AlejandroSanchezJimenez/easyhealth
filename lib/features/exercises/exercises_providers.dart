import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import '../../shared/data/content_repository.dart';
import 'domain/exercise.dart';

final exerciseRemoteProvider = Provider((ref) => ContentRemote<Exercise>(
    ref.watch(firestoreProvider),
    FirestorePaths.exercises,
    Exercise.fromMap,
    (e) => e.toMap()));

/// Usuarios: solo publicados.
final exercisesProvider = StreamProvider<List<Exercise>>(
    (ref) => ref.watch(exerciseRemoteProvider).watchPublished());

/// Maestros: todos los estados.
final allExercisesProvider = StreamProvider<List<Exercise>>(
    (ref) => ref.watch(exerciseRemoteProvider).watchAll());

final exercisesByDiseaseProvider =
    Provider.family<AsyncValue<List<Exercise>>, String>((ref, diseaseId) => ref
        .watch(exercisesProvider)
        .whenData(
            (l) => l.where((e) => e.diseaseIds.contains(diseaseId)).toList()));
