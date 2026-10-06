/**
 * Cálculo de racha. Puro, sin dependencias de Firebase, para poder testearlo
 * con `node` sin instalar nada.
 *
 * Es un espejo de `StreakCalculator.compute` en
 * `lib/features/streak/domain/streak_stats.dart`: si cambias uno, cambia el
 * otro, o las cifras de "Amigos" no cuadrarán con las del propio usuario.
 */

/// Clave de día "yyyy-MM-dd".
function dateKey(d) {
  return (
    String(d.getFullYear()).padStart(4, "0") +
    "-" +
    String(d.getMonth() + 1).padStart(2, "0") +
    "-" +
    String(d.getDate()).padStart(2, "0")
  );
}

/// 'yyyy-MM-dd' -> medianoche UTC (evita que el cambio horario desplace días).
function asDate(key) {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

/**
 * @param {Object<string, number>} secondsByDay  clave de día -> segundos
 * @param {Date} today
 */
function computeStats(secondsByDay, today) {
  const days = Object.keys(secondsByDay).sort();
  if (days.length === 0) {
    return {
      currentStreak: 0,
      longestStreak: 0,
      totalExerciseDays: 0,
      totalExerciseSeconds: 0,
      lastExerciseDate: null,
    };
  }

  let longest = 1;
  let run = 1;
  for (let i = 1; i < days.length; i++) {
    const gap = (asDate(days[i]) - asDate(days[i - 1])) / 86400000;
    run = gap === 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  // La racha sigue viva si el último día fue hoy o ayer.
  const gapToToday =
    (asDate(dateKey(today)) - asDate(days[days.length - 1])) / 86400000;
  let current = 0;
  if (gapToToday <= 1) {
    current = 1;
    for (let i = days.length - 1; i > 0; i--) {
      const gap = (asDate(days[i]) - asDate(days[i - 1])) / 86400000;
      if (gap === 1) current++;
      else break;
    }
  }

  const totalExerciseSeconds = Object.values(secondsByDay).reduce(
    (a, b) => a + b,
    0,
  );

  return {
    currentStreak: current,
    longestStreak: longest,
    totalExerciseDays: days.length,
    totalExerciseSeconds,
    lastExerciseDate: days[days.length - 1],
  };
}

module.exports = { computeStats, dateKey, asDate };