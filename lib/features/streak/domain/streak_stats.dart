import '../../../core/utils/date_key.dart';

class StreakStats {
  const StreakStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalExerciseDays = 0,
    this.lastExerciseDate,
    this.totalExerciseSeconds = 0,
  });
  final int currentStreak, longestStreak, totalExerciseDays, totalExerciseSeconds;
  final String? lastExerciseDate;
}

/// Función pura: el historial es la fuente de verdad; la racha se DERIVA.
/// Sirve para reconstruir/verificar en cualquier dispositivo y tras sincronizar.
class StreakCalculator {
  static StreakStats compute({
    required Map<String, int> secondsByDay, // dateKey -> segundos totales
    required DateTime today,
  }) {
    if (secondsByDay.isEmpty) return const StreakStats();
    final days = secondsByDay.keys.map(parseDateKey).toList()..sort();

    var longest = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      run = days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }

    // La racha sigue viva si el último día es hoy o ayer.
    final t = parseDateKey(dateKey(today));
    final gap = t.difference(days.last).inDays;
    var current = 0;
    if (gap <= 1) {
      current = 1;
      for (var i = days.length - 1; i > 0; i--) {
        if (days[i].difference(days[i - 1]).inDays == 1) {
          current++;
        } else {
          break;
        }
      }
    }

    return StreakStats(
      currentStreak: current,
      longestStreak: longest,
      totalExerciseDays: days.length,
      lastExerciseDate: dateKey(days.last),
      totalExerciseSeconds: secondsByDay.values.fold(0, (a, b) => a + b),
    );
  }
}
