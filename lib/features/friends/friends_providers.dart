import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers.dart';
import '../auth/auth_providers.dart';
import 'domain/friend.dart';

/// Referencia a la subcolección de vínculos de [uid].
CollectionReference<Map<String, dynamic>> _linksOf(Ref ref, String uid) =>
    ref.read(firestoreProvider).collection(FirestorePaths.friends(uid));

/// Lista de MIS vínculos. Cada documento es un amigo visto desde mi cuenta.
final friendsProvider = StreamProvider<List<Friend>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.friends(uid))
      .snapshots()
      .map((snap) {
    final list = snap.docs
        .map((d) => Friend.fromMap(d.id, Map<String, dynamic>.from(d.data())))
        .toList();
    // Aceptados primero; dentro, por nombre para que sea estable.
    list.sort((a, b) {
      if (a.status != b.status) {
        return a.status == FriendStatus.accepted ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return list;
  });
});

/// Solicitudes que me espera a mí responder (las pidió otro y siguen pending).
final pendingRequestsProvider = Provider<List<Friend>>((ref) {
  final me = ref.watch(currentUserProvider)?.uid;
  final all = ref.watch(friendsProvider).valueOrNull ?? const <Friend>[];
  if (me == null) return const [];
  return all.where((f) => f.isPendingFrom(me)).toList();
});

/// Resumen de racha de cada amigo ACEPTADO.
///
/// Documento a documento con `get`, nunca `list`: las reglas permiten leer
/// `userStreaks/{uid}` pero no enumerar la colección.
final friendsStreaksProvider =
    FutureProvider<Map<String, ResolvedStreak>>((ref) async {
  final me = ref.watch(currentUserProvider)?.uid;
  final friends = (ref.watch(friendsProvider).valueOrNull ?? const <Friend>[])
      .where((f) => f.status == FriendStatus.accepted)
      .toList();
  if (me == null || friends.isEmpty) return const {};

  final fs = ref.watch(firestoreProvider);
  final entries = await Future.wait(friends.map((f) async {
    try {
      final doc =
          await fs.collection(FirestorePaths.userStreaks).doc(f.uid).get();
      if (!doc.exists) return MapEntry(f.uid, _noData);
      return MapEntry(
        f.uid,
        resolveFriendStreak(
          FriendStreak.fromMap(Map<String, dynamic>.from(doc.data()!)),
        ),
      );
    } catch (_) {
      // Si una regla deniega la lectura, no debe romperse toda la pantalla.
      return MapEntry(f.uid, _noData);
    }
  }));
  return Map.fromEntries(entries);
});

const _noData = ResolvedStreak(streak: 0, inactiveDays: null, hasData: false);

/// Mi código de invitación, p. ej. `K7X2M9`.
///
/// Se guarda en `inviteCodes/{code}` apuntando a mi uid, con nombre y foto,
/// para que quien teclee el código NO tenga que leer mi documento privado.
/// Se recupera con una consulta filtrada por mi uid (las reglas la limitan a
/// devolver solo los documentos propios).
final inviteCodeProvider = FutureProvider<String?>((ref) async {
  final me = ref.watch(currentUserProvider);
  if (me == null) return null;

  final codes = ref.read(firestoreProvider).collection(FirestorePaths.inviteCodes);
  final mine =
      await codes.where('uid', isEqualTo: me.uid).limit(1).get();
  if (mine.docs.isNotEmpty) return mine.docs.first.id;

  final code = _generateCode();
  await codes.doc(code).set({
    'uid': me.uid,
    'displayName': _myName(me),
    'photoUrl': me.photoUrl,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return code;
});

/// Alfabeto sin 0/O/1/I, para dictarlo sin equivocarse.
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _generateCode() {
  final r = Random();
  return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

String _myName(dynamic me) {
  final d = (me.displayName as String?)?.trim();
  if (d != null && d.isNotEmpty) return d;
  return (me.email as String?)?.split('@').first ?? 'Usuario';
}

// ───────────────────────── Acciones ─────────────────────────

/// Añade a un amigo con su código de invitación.
///
/// Escribe los DOS documentos espejo en `pending` (el mío y el suyo), así el
/// vínculo es mutuo desde el principio y ambos lo ven en su lista.
///
/// OJO: si el vínculo YA EXISTE hay que resolverlo, no reescribirlo. En
/// Firestore, `set()` sobre un documento existente cuenta como UPDATE, y la
/// regla de update solo deja pasar a `accepted`. Un `set()` con `pending`
/// daría PERMISSION_DENIED. Ocurre, por ejemplo, cuando la otra persona ya te
/// añadió a ti antes.
final addFriendProvider = Provider((ref) => (String rawCode) async {
      final me = ref.read(currentUserProvider);
      if (me == null) throw StateError('No hay sesión abierta.');

      final code = rawCode.trim().toUpperCase();
      if (code.isEmpty) throw StateError('Introduce un código.');

      final fs = ref.read(firestoreProvider);
      final snap = await fs
          .collection(FirestorePaths.inviteCodes)
          .doc(code)
          .get();
      if (!snap.exists) throw StateError('Ese código no existe.');

      final data = Map<String, dynamic>.from(snap.data()!);
      final otherUid = data['uid'] as String?;
      if (otherUid == null || otherUid.isEmpty) {
        throw StateError('Ese código no es válido.');
      }
      if (otherUid == me.uid) throw StateError('Ese código es el tuyo.');

      final otherName = data['displayName'] as String? ?? 'tu amigo';

      // ¿Existe ya un vínculo en mi lista?
      final existing = await _linksOf(ref, me.uid).doc(otherUid).get();
      if (existing.exists) {
        final m = Map<String, dynamic>.from(existing.data() ?? const {});
        final status = FriendStatus.parse(m['status'] as String?);
        final requestedBy = m['requestedBy'] as String?;

        if (status == FriendStatus.accepted) {
          return '$otherName ya está en tu lista.';
        }
        if (requestedBy == me.uid) {
          return 'Ya le enviaste una solicitud a $otherName. '
              'Falta que la acepte.';
        }
        // Pendiente y la pidió él/ella: meter el código equivale a aceptar.
        // Se hace con update (merge) para que la regla lo permita.
        await ref.read(acceptFriendProvider)(Friend(
              uid: otherUid,
              status: status,
              requestedBy: requestedBy ?? otherUid,
              displayName: otherName,
              photoUrl: data['photoUrl'] as String?,
            ));
        return '¡Hecho! Ahora tú y $otherName sois amigos.';
      }

      // Vínculo nuevo: se escriben los DOS espejos en `pending`.
      final link = {
        'status': FriendStatus.pending.name,
        'requestedBy': me.uid,
        'displayName': otherName,
        'photoUrl': data['photoUrl'] as String?,
      };

      await _linksOf(ref, me.uid).doc(otherUid).set({
        ...link,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _linksOf(ref, otherUid).doc(me.uid).set({
        ...link,
        // El suyo aún no conoce MI nombre: se lo escribo ahora.
        'displayName': _myName(me),
        'photoUrl': me.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return 'Solicitud enviada a $otherName.';
    });

/// Acepta una solicitud pendiente: ambos documentos pasan a `accepted`.
final acceptFriendProvider = Provider((ref) => (Friend f) async {
      final me = ref.read(currentUserProvider);
      if (me == null) throw StateError('No hay sesión abierta.');

      final accepted = {
        'status': FriendStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
      };
      // Mi documento ya trae el nombre del amigo desnormalizado.
      await _linksOf(ref, me.uid)
          .doc(f.uid)
          .set(accepted, SetOptions(merge: true));
      // En el suyo escribo MI nombre, que antes no conocía.
      await _linksOf(ref, f.uid).doc(me.uid).set({
        ...accepted,
        'displayName': _myName(me),
        'photoUrl': me.photoUrl,
      }, SetOptions(merge: true));
    });

/// Rechaza o elimina un vínculo: borra los dos documentos espejo.
final removeFriendProvider = Provider((ref) => (Friend f) async {
      final me = ref.read(currentUserProvider)?.uid;
      if (me == null) return;
      await _linksOf(ref, me).doc(f.uid).delete();
      await _linksOf(ref, f.uid).doc(me).delete();
    });