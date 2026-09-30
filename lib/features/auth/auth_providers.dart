import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/auth_repository.dart';
import 'domain/app_user.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(
    ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)));

final authStateProvider = StreamProvider<AppUser?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());

final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authStateProvider).valueOrNull);

/// Solo cambia cuando cambia la cuenta (no en refrescos de token ni de rol).
final uidProvider = Provider<String?>(
    (ref) => ref.watch(currentUserProvider.select((u) => u?.uid)));
