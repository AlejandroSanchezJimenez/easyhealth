/**
 * Calcula el resumen público de racha de cada usuario y lo deja en
 * `userStreaks/{uid}`, que es lo único que los amigos pueden leer.
 *
 * Por qué una Function y no el cliente:
 *   - `userStreaks` tiene `allow write: if false`, así que el cliente no
 *     puede falsear su propia racha ni la de nadie.
 *   - El cliente tampoco puede leer el historial de otros usuarios.
 *
 * Se dispara con un onDocumentWritten de cada sesión completada. Es
 * idempotente: recalcula desde cero sobre todo el historial.
 *
 * REGLAS que necesita (añadir a firestore.rules):
 *
 *   match /userStreaks/{uid} {
 *     allow read: if request.auth != null;
 *     allow write: if false;              // solo el Admin SDK
 *   }
 *
 * Esta función usa el Admin SDK, que ignora las reglas de seguridad.
 */
const admin = require("firebase-admin");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/logger");
const { computeStats } = require("./streak_stats");

admin.initializeApp();

const db = admin.firestore();

/** Recalcula el resumen de un usuario desde su historial completo. */
async function recompute(uid) {
  const snap = await db.collection("users").doc(uid).collection("history").get();

  const secondsByDay = {};
  snap.docs.forEach((doc) => {
    const data = doc.data();
    // Descarta registros corruptos en vez de romper el cálculo.
    if (typeof data.dateKey !== "string" || typeof data.seconds !== "number") {
      return;
    }
    secondsByDay[data.dateKey] =
      (secondsByDay[data.dateKey] || 0) + data.seconds;
  });

  const stats = computeStats(secondsByDay, new Date());
  await db.collection("userStreaks").doc(uid).set(
    {
      ...stats,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return stats;
}

/**
 * onDocumentWritten (y no onDocumentCreated) para que también dispare la
 * reentrada idempotente que hace el cliente con las sesiones pendientes al
 * recuperar la conexión.
 *
 * Región `europe-west3` para que coincida con la instancia de Firestore
 * (eur3) y no haya saltos entre regiones en cada disparo.
 */
exports.onSessionWritten = onDocumentWritten(
  {
    document: "users/{uid}/history/{sessionId}",
    region: "europe-west3",
  },
  async (event) => {
    const before = event.data && event.data.before;
    const after = event.data && event.data.after;

    if (before && before.exists && after && after.exists) return; // update
    if (!after || !after.exists) return; // borrado (`allow delete: if false`)

    const uid = event.params.uid;
    try {
      const stats = await recompute(uid);
      logger.info(
        `racha de ${uid}: ${stats.currentStreak} días ` +
          `(${stats.totalExerciseDays} totales, último ${stats.lastExerciseDate})`,
      );
    } catch (e) {
      logger.error(`no se pudo recalcular la racha de ${uid}`, e);
      throw e; // para que reintente
    }
  },
);