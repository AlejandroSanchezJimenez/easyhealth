import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import '../../shared/data/content_repository.dart';
import 'data/offline_library.dart';
import 'data/workout_downloader.dart';
import 'domain/video_meta.dart';
import '../auth/auth_providers.dart';

final videoRemoteProvider = Provider((ref) => ContentRemote<VideoMeta>(
    ref.watch(firestoreProvider),
    FirestorePaths.videos,
    VideoMeta.fromMap,
    (v) => v.toMap()));

/// Usuarios: solo publicados.
final videosProvider = StreamProvider<List<VideoMeta>>((ref) {
  if (ref.watch(uidProvider) == null) return const Stream.empty();
  return ref.watch(videoRemoteProvider).watchPublished();
});

/// Maestros: todos los estados.
final allVideosProvider = StreamProvider<List<VideoMeta>>((ref) {
  if (ref.watch(uidProvider) == null) return const Stream.empty();
  return ref.watch(videoRemoteProvider).watchAll();
});

final offlineLibraryProvider =
    Provider((ref) => OfflineLibrary(ref.watch(sharedPrefsProvider)));

final workoutDownloaderProvider = Provider((ref) => WorkoutDownloader(
    ref.watch(downloadManagerProvider), ref.watch(offlineLibraryProvider)));

final videoByIdProvider = Provider.family<VideoMeta?, String>((ref, id) {
  final list = ref.watch(videosProvider).valueOrNull ?? const <VideoMeta>[];
  return list.where((v) => v.id == id).firstOrNull;
});
