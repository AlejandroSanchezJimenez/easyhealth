import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._auth, this._fs);
  final FirebaseAuth _auth;
  final FirebaseFirestore _fs;

  /// El rol se lee del token (Custom Claims asignadas por Cloud Function/admin).
  Stream<AppUser?> authStateChanges() => _auth.idTokenChanges().asyncMap((u) async {
        if (u == null) return null;
        final t = await u.getIdTokenResult();
        return AppUser(
          uid: u.uid,
          email: u.email,
          displayName: u.displayName,
          photoUrl: u.photoURL,
          role: UserRole.parse(t.claims?['role'] as String?),
        );
      });

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> register(String email, String password, {String? displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(displayName);
    // NO se escribe `role` desde el cliente. Las reglas lo prohíben.
    await _fs.collection(FirestorePaths.users).doc(cred.user!.uid).set({
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);
  Future<void> signOut() => _auth.signOut();
}
