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
const { onCall, HttpsError } = require("firebase-functions/v2/https");
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

// ───────────────────────── Borrado de cuenta (RGPD) ─────────────────────────

/// Bucket por defecto del proyecto. Se fija a mano porque el nombre nuevo
/// (`<proyecto>.firebasestorage.app`) no siempre coincide con el que el Admin
/// SDK deduce solo (`<proyecto>.appspot.com`).
const STORAGE_BUCKET = "easyhealth-96183.firebasestorage.app";

/**
 * Borra la cuenta de quien llama y TODOS sus datos.
 *
 * Por qué en el servidor: las reglas del cliente prohíben borrar el historial,
 * `progress`, `streak` y `userStreaks` (están puestos como `allow write: if
 * false`), y nadie puede borrarse su propia cuenta de Auth desde el cliente sin
 * volver a autenticarse. El Admin SDK ignora todo eso.
 *
 * La contraseña NO se comprueba aquí: el cliente se re-autentica ANTES de
 * llamar, y eso es lo que verifica la contraseña. Aun así, un cliente
 * malicioso solo podría borrar SU PROPIA cuenta (el uid sale del token), así
 * que no hay riesgo.
 */
exports.deleteMyAccount = onCall(
  { region: "europe-west3" },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Tienes que iniciar sesión.");
    }

    // 1. Vínculos espejo en las listas de mis amigos, para no dejar
    //    referencias a una cuenta que ya no existe.
    const myLinks = await db
      .collection("users")
      .doc(uid)
      .collection("friends")
      .get();
    await Promise.all(
      myLinks.docs.map((d) =>
        db
          .collection("users")
          .doc(d.id)
          .collection("friends")
          .doc(uid)
          .delete()
          .catch(() => {}),
      ),
    );

    // 2. Códigos de invitación que apunten a mí.
    const codes = await db
      .collection("inviteCodes")
      .where("uid", "==", uid)
      .get();
    await Promise.all(codes.docs.map((d) => d.ref.delete().catch(() => {})));

    // 3. Datos públicos.
    await db.collection("userProfiles").doc(uid).delete().catch(() => {});
    await db.collection("userStreaks").doc(uid).delete().catch(() => {});

    // 4. Mi documento y TODAS sus subcolecciones (history, friends, progress,
    //    streak) de una sola pasada.
    await db.recursiveDelete(db.collection("users").doc(uid));

    // 5. Foto de perfil en Storage.
    try {
      await admin
        .storage()
        .bucket(STORAGE_BUCKET)
        .deleteFiles({ prefix: `users/${uid}/` });
    } catch (e) {
      logger.warn(`no se pudieron borrar los archivos de ${uid}`, e);
    }

    // 6. La cuenta de Auth, AL FINAL: si algo falla antes, la cuenta sigue
    //    existiendo y el usuario puede reintentarlo.
    await admin.auth().deleteUser(uid);

    logger.info(`cuenta borrada: ${uid}`);
    return { ok: true };
  },
);