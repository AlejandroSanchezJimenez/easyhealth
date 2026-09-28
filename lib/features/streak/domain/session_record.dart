import 'package:cloud_firestore/cloud_firestore.dart';

/// Una sesión completada. El `id` (uuid) hace que subirla dos veces no duplique nada.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.uid,
    required this.dateKey,
    required this.kind, // exercise | workout | daily
    required this.refId,
    required this.seconds,
    required this.completedAt,
  });

  final String id, uid, dateKey, kind, refId;
  final int seconds;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'id': id, 'uid': uid, 'dateKey': dateKey, 'kind': kind, 'refId': refId,
        'seconds': seconds, 'completedAt': completedAt.toUtc().toIso8601String(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> m) => SessionRecord(
        id: m['id'] as String,
        uid: m['uid'] as String,
        dateKey: m['dateKey'] as String,
        kind: m['kind'] as String,
        refId: m['refId'] as String,
        seconds: (m['seconds'] as num).toInt(),
        completedAt: DateTime.parse(m['completedAt'] as String),
      );

  Map<String, dynamic> toFirestore() => {
        'dateKey': dateKey, 'kind': kind, 'refId': refId, 'seconds': seconds,
        'completedAt': Timestamp.fromDate(completedAt),
      };

  factory SessionRecord.fromFirestore(String uid, String id, Map<String, dynamic> m) => SessionRecord(
        id: id,
        uid: uid,
        dateKey: m['dateKey'] as String? ?? '',
        kind: m['kind'] as String? ?? 'exercise',
        refId: m['refId'] as String? ?? '',
        seconds: (m['seconds'] as num?)?.toInt() ?? 0,
        completedAt: (m['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
