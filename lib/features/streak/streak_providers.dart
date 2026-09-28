import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sync/sync_service.dart';
import '../auth/auth_providers.dart';
import 'data/history_repository.dart';
import 'data/pending_sessions_store.dart';
import 'domain/session_record.dart';
import 'domain/streak_stats.dart';

final historyRepositoryProvider = Provider((ref) => HistoryRepository(
      ref.watch(firestoreProvider),
      PendingSessionsStore(ref.watch(sharedPrefsProvider)),
    ));

final sessionsProvider = StreamProvider<List<SessionRecord>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(historyRepositoryProvider).watchSessions(user.uid);
});

/// La racha se calcula siempre a partir del historial.
final streakStatsProvider = Provider<AsyncValue<StreakStats>>((ref) =>
    ref.watch(sessionsProvider).whenData((sessions) {
      final byDay = <String, int>{};
      for (final s in sessions) {
        byDay.update(s.dateKey, (v) => v + s.seconds, ifAbsent: () => s.seconds);
      }
      return StreakCalculator.compute(secondsByDay: byDay, today: DateTime.now());
    }));

/// Al volver la conexión sube las sesiones pendientes.
final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(ref.watch(connectivityProvider), () async {
    final user = ref.read(currentUserProvider);
    if (user != null) await ref.read(historyRepositoryProvider).pushPending(user.uid);
  })..start();
  ref.onDispose(s.dispose);
  return s;
});
