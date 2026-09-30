import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import '../../shared/data/content_repository.dart';
import '../auth/auth_providers.dart';
import 'domain/disease.dart';

final diseaseRemoteProvider = Provider((ref) => ContentRemote<Disease>(
    ref.watch(firestoreProvider),
    FirestorePaths.diseases,
    Disease.fromMap,
    (d) => d.toMap()));

/// Usuarios: solo publicados. Se recrea al cambiar de cuenta.
final diseasesProvider = StreamProvider<List<Disease>>((ref) {
  if (ref.watch(uidProvider) == null) return const Stream.empty();
  return ref.watch(diseaseRemoteProvider).watchPublished();
});

/// Maestros: todos los estados.
final allDiseasesProvider = StreamProvider<List<Disease>>((ref) {
  if (ref.watch(uidProvider) == null) return const Stream.empty();
  return ref.watch(diseaseRemoteProvider).watchAll();
});
