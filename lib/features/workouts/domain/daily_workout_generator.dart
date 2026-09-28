import 'dart:math';

/// Determinista: mismos (uid, enfermedad, fecha, ejercicios) => mismo resultado.
class DailyWorkoutGenerator {
  /// FNV-1a: estable entre ejecuciones y plataformas (String.hashCode no lo garantiza).
  static int _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static List<String> generate({
    required String uid,
    required String diseaseId,
    required String dateKey,
    required List<String> availableIds,
    Set<String> recentIds = const {},
    int count = 4,
  }) {
    if (availableIds.isEmpty) return const [];
    final all = [...availableIds]..sort(); // orden estable antes de barajar
    var pool = all.where((i) => !recentIds.contains(i)).toList();
    if (pool.length < count) pool = all; // no hay suficientes "nuevos"
    pool.shuffle(Random(_fnv1a('$uid|$diseaseId|$dateKey')));
    return pool.take(count).toList();
  }
}
