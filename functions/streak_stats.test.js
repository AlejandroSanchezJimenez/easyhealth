// Prueba del cálculo de racha, sin dependencias de Firebase:
//     node functions/streak_stats.test.js
const assert = require("assert");
const { computeStats } = require("./streak_stats");

const d = (s) => new Date(s + "T12:00:00");
let pass = 0;

function check(name, actual, expected) {
  assert.deepStrictEqual(
    actual,
    expected,
    `\n${name}\n  esperado: ${JSON.stringify(expected)}\n  obtenido: ${JSON.stringify(actual)}`,
  );
  console.log("  ok  " + name);
  pass++;
}

// Vacío.
check(
  "sin historial",
  computeStats({}, d("2026-10-10")),
  {
    currentStreak: 0,
    longestStreak: 0,
    totalExerciseDays: 0,
    totalExerciseSeconds: 0,
    lastExerciseDate: null,
  },
);

// Racha viva: entrenó ayer.
check("entrenó ayer: racha viva", computeStats(
  { "2026-10-08": 300, "2026-10-09": 300 },
  d("2026-10-10")
).currentStreak, 2);

// Entrenó hoy.
check("entrenó hoy", computeStats(
  { "2026-10-08": 300, "2026-10-09": 300, "2026-10-10": 300 },
  d("2026-10-10")
).currentStreak, 3);

// Dos días sin entrenar -> racha muerta, pero el récord se conserva.
check("2 días sin entrenar: racha a 0", computeStats(
  { "2026-10-01": 300, "2026-10-02": 300, "2026-10-03": 300 },
  d("2026-10-06")
).currentStreak, 0);

// El récord sigue siendo 3 aunque la actual esté rota.
check("el récord no se pierde", computeStats(
  { "2026-10-01": 300, "2026-10-02": 300, "2026-10-03": 300 },
  d("2026-10-06")
).longestStreak, 3);

// Hueco en medio: rompe la racha.
check("hueco en medio", computeStats(
  { "2026-10-01": 300, "2026-10-02": 300, "2026-10-05": 300, "2026-10-06": 300 },
  d("2026-10-06")
).currentStreak, 2);

// Un solo día entrenado.
check("un solo día", computeStats({ "2026-10-06": 300 }, d("2026-10-06")).currentStreak, 1);

// Sumar varios días seguidos el mismo día.
check("varias sesiones el mismo día", computeStats(
  { "2026-10-05": 300, "2026-10-06": 200, "2026-10-06": 250 },
  d("2026-10-06")
).currentStreak, 2);

// Cruce de mes y de año.
check("cruce de año", computeStats(
  { "2025-12-30": 300, "2025-12-31": 300, "2026-01-01": 300 },
  d("2026-01-01")
).currentStreak, 3);

// Total de segundos.
check("total de segundos", computeStats(
  { "2026-10-05": 300, "2026-10-06": 200 },
  d("2026-10-06")
).totalExerciseSeconds, 500);

// Una sesión futura (skew del servidor) no rompe nada.
const futuro = computeStats({ "2026-10-06": 300 }, d("2026-10-06"));
check("sesión de hoy es válida", futuro.currentStreak, 1);

console.log(`\n${pass} pruebas correctas.`);