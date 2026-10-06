import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import 'data/auth_repository.dart';
import 'domain/app_user.dart';

/// MIME de las extensiones que suelta el selector de galería.
String? contentTypeFor(String ext) => switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => null,
    };

final authRepositoryProvider = Provider((ref) => AuthRepository(
    ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)));

final authStateProvider = StreamProvider<AppUser?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());

final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authStateProvider).valueOrNull);

/// Solo cambia cuando cambia la cuenta (no en refrescos de token ni de rol).
final uidProvider = Provider<String?>(
    (ref) => ref.watch(currentUserProvider.select((u) => u?.uid)));

/// Datos del perfil que edita el propio usuario (por ahora, la foto).
///
/// La foto NO se guarda en Firebase Auth: `User.photoURL` viene vacío en las
/// cuentas creadas con email/contraseña, así que la fuente de verdad es el
/// documento `users/{uid}`.
final userProfileProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.users)
      .doc(uid)
      .snapshots()
      .map((s) => s.data());
});

/// URL de la foto de perfil, o null si el usuario aún no ha puesto ninguna.
final userPhotoUrlProvider = Provider<String?>((ref) {
  final url = ref.watch(userProfileProvider).valueOrNull?['photoUrl'];
  return (url is String && url.isNotEmpty) ? url : null;
});

/// Sube una imagen a Storage y guarda su URL en el documento del usuario.
/// Devuelve la URL nueva.
final uploadProfilePhotoProvider =
    Provider((ref) => (File file) async {
          final uid = ref.read(uidProvider);
          if (uid == null) throw StateError('No hay sesión iniciada.');

          // Extensión a partir del nombre: evita subir siempre .jpg algo que no
          // lo es (PNG, HEIC de iPhone...).
          final ext = (file.path.split('.').last).toLowerCase();
          final safeExt = ext.length <= 5 && RegExp(r'^[a-z0-9]+$').hasMatch(ext)
              ? ext
              : 'jpg';
          // La ruta DEBE coincidir con las reglas de Storage, que declaran
          // `match /users/{uid}/avatar/{fileName}`: son TRES segmentos
          // (users / uid / avatar / nombre). Con dos, la escritura no encaja
          // en ninguna regla y cae en el deny por defecto.
          final path = 'users/$uid/avatar/profile.$safeExt';

          final storage = ref.read(storageProvider);

          // Si la extensión cambia (jpg -> png) el objeto anterior quedaría
          // huérfano en Storage, así que se borra antes de subir el nuevo.
          final previous =
              ref.read(userProfileProvider).valueOrNull?['photoUrl'];
          if (previous is String && previous.isNotEmpty) {
            try {
              await storage.refFromURL(previous).delete();
            } catch (_) {
              // Si ya no existe, se sigue con la subida.
            }
          }

          final storageRef = storage.ref(path);
          await storageRef.putFile(
            file,
            SettableMetadata(contentType: contentTypeFor(safeExt)),
          );
          final url = await storageRef.getDownloadURL();

          await _writePhotoUrl(ref, uid, url);
          return url;
        });

/// Escribe `photoUrl` en `users/{uid}`.
///
/// Son dos caminos porque tus reglas separan `create` de `update` y cada una
/// exige campos distintos:
///
/// - `create` pide `email`, `createdAt`, `updatedAt` y prohíbe `role`.
/// - `update` evalúa `request.resource.data.displayName`, y si el documento no
///   tiene esa clave, ese acceso da ERROR y deniega la escritura entera.
///
/// Un `set(..., merge: true)` a secas no garantiza ninguna de las dos cosas:
/// si el documento no existe, `merge` degrada en un `create` sin `email`.
Future<void> _writePhotoUrl(Ref ref, String uid, String? photoUrl) async {
  final auth = ref.read(firebaseAuthProvider);
  final doc =
      ref.read(firestoreProvider).collection(FirestorePaths.users).doc(uid);
  final snap = await doc.get();
  final data = snap.data();

  if (!snap.exists) {
    // Alta: se rellena todo lo que la regla de create exige.
    await doc.set({
      'email': auth.currentUser?.email,
      'displayName': auth.currentUser?.displayName,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return;
  }

  // Edición: `displayName` se reenvía aunque no cambie, para que la clave
  // exista siempre y la regla pueda evaluarla sin error.
  await doc.set({
    'displayName': data?['displayName'],
    'photoUrl': photoUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Borra la foto de Storage y limpia el campo del documento.
final removeProfilePhotoProvider = Provider((ref) => () async {
      final uid = ref.read(uidProvider);
      if (uid == null) return;
      final data = ref.read(userProfileProvider).valueOrNull;
      final url = data?['photoUrl'];
      if (url is String && url.isNotEmpty) {
        try {
          await ref.read(storageProvider).refFromURL(url).delete();
        } catch (_) {
          // Si el objeto ya no existe, se sigue limpiando el documento.
        }
      }
      await _writePhotoUrl(ref, uid, null);
    });
