import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import '../../shared/data/content_repository.dart';
import 'domain/disease.dart';

final diseaseRemoteProvider = Provider((ref) => ContentRemote<Disease>(
    ref.watch(firestoreProvider),
    FirestorePaths.diseases,
    Disease.fromMap,
    (d) => d.toMap()));

/// Usuarios: solo publicados.
final diseasesProvider = StreamProvider<List<Disease>>(
    (ref) => ref.watch(diseaseRemoteProvider).watchPublished());

/// Maestros: todos los estados.
final allDiseasesProvider = StreamProvider<List<Disease>>(
    (ref) => ref.watch(diseaseRemoteProvider).watchAll());
