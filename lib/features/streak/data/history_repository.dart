import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../app/config.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/utils/date_key.dart';
import '../domain/session_record.dart';
import 'pending_sessions_store.dart';

/// Firebase es la fuente de verdad del historial. Localmente solo se guardan
/// las sesiones aún no confirmadas, para no perder la racha sin conexión.
class HistoryRepository {
  HistoryRepository(this._fs, this._pending);
  final FirebaseFirestore _fs;
  final PendingSessionsStore _pending;

  Future<void> completeSession({
    required String uid,
    required String kind,
    required String refId,
    required int seconds,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final s = SessionRecord(
      id: const Uuid().v4(),
      uid: uid,
      dateKey: dateKey(at),
      kind: kind,
      refId: refId,
      seconds: seconds,
      completedAt: at,
    );
    await _pending.add(s); // 1) seguro local
    unawaited(_push(s)); // 2) Firebase (sin bloquear la UI si no hay red)
  }

  Future<bool> _push(SessionRecord s) async {
    try {
      await _fs
          .collection(FirestorePaths.history(s.uid))
          .doc(s.id)
          .set(s.toFirestore(), SetOptions(merge: true))
          .timeout(AppConfig.syncTimeout);
      await _pending.remove(s.id);
      return true;
    } catch (_) {
      return false; // queda pendiente; se reintenta al volver la conexión
    }
  }

  Future<void> pushPending(String uid) async {
    for (final s in _pending.all(uid)) {
      await _push(s);
    }
  }

  /// Historial de Firebase + sesiones pendientes (deduplicadas por id).
  Stream<List<SessionRecord>> watchSessions(String uid) =>
      _fs.collection(FirestorePaths.history(uid)).snapshots().map((snap) {
        final byId = {
          for (final d in snap.docs) d.id: SessionRecord.fromFirestore(uid, d.id, d.data()),
        };
        for (final p in _pending.all(uid)) {
          byId.putIfAbsent(p.id, () => p);
        }
        return byId.values.toList();
      });
}
