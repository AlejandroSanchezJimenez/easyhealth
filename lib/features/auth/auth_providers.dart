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
          // El prefijo 'users/' NO es opcional: las reglas de Storage declara
          // `match /users/{uid}/{fileName}`. Sin él, la ruta <uid>/avatar.jpg
          // no encaja en ninguna regla y cae en el deny por defecto.
          final path = 'users/$uid/avatar.$safeExt';

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

          await ref
              .read(firestoreProvider)
              .collection(FirestorePaths.users)
              .doc(uid)
              .set({
                'photoUrl': url,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          return url;
        });

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
      await ref
          .read(firestoreProvider)
          .collection(FirestorePaths.users)
          .doc(uid)
          .set({'photoUrl': null, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
    });
