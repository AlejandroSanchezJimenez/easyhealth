# Decisiones de arquitectura

## Principio
**Firebase es la fuente principal de todo.** El modo sin conexión es una llamada de
emergencia: guarda solo lo mínimo para poder usar clases ya descargadas y no perder la racha.
No hay base de datos local.

## Qué vive dónde
| Dato | Fuente principal | Emergencia sin red |
|---|---|---|
| Enfermedades, ejercicios, clases | Cloud Firestore | Caché interna de Firestore (`persistenceEnabled`) |
| Vídeos | Firebase Storage | Archivos descargados en `documents/offline/` |
| Datos de una clase descargada | Firestore | Instantánea JSON en `OfflineLibrary` (SharedPreferences) |
| Historial y racha | `users/{uid}/history` en Firestore | Cola `PendingSessionsStore` (SharedPreferences) |

## Decisiones
| Tema | Decisión |
|---|---|
| Estado | Riverpod |
| Navegación | go_router + StatefulShellRoute; guardas por sesión y rol |
| Rol | Custom Claims (`role`) en el ID token; el cliente no puede asignárselo |
| Estado del contenido | `status` = draft / published / archived |
| Versionado | El servidor incrementa `version` en cada guardado |
| Descarga | Por CLASE: sus vídeos + ejercicios. Reanudable (Range), validación de tamaño |
| Vídeos compartidos | Un vídeo usado por varias clases se guarda una vez y solo se borra si nadie lo usa |
| Actualizaciones | `isOutdated` compara versión local y del servidor |
| Racha | Se calcula desde el historial (`StreakCalculator`); no se guarda como dato principal |
| Sesión completada | 1) se guarda en pendientes 2) se sube a Firebase 3) se borra de pendientes al confirmarse |
| Idempotencia | ID de sesión = uuid; subirla dos veces no duplica |
| Entrenamiento diario | Semilla FNV-1a(uid, enfermedad, fecha). No se guarda: se recalcula igual |
| Colores | Solo `app/theme/app_palette.dart` |

## Puntos abiertos
1. **Paleta remota** en Firestore: ¿Fase 1 o Fase 7?
2. **Zona horaria de la racha**: hoy cuenta el día local del dispositivo.
3. **Diario estable**: si un maestro publica/despublica un ejercicio durante el día, el entrenamiento de hoy puede cambiar. ¿Fijarlo al primer cálculo del día?
4. **Descarga por clase o por enfermedad**: ahora es por clase; se puede añadir "descargar todo" que las encadene.
5. **Espacio libre**: no se comprueba aún (requiere un plugin adicional).
6. **Asignar rol teacher**: Cloud Function protegida por admin.

## Pendiente
- `firestore.rules` y `storage.rules`.
- Cloud Function `setUserRole`.
- `flutterfire configure`.
- Tests de `StreakCalculator` y `DailyWorkoutGenerator`.
