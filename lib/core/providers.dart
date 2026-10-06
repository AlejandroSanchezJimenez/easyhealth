import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'downloads/download_manager.dart';
import 'network/connectivity_service.dart';
import 'notifications/notification_service.dart';

final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final storageProvider = Provider((_) => FirebaseStorage.instance);

/// Cloud Functions.
///
/// La región DEBE coincidir con la del despliegue en `functions/index.js`, o
/// la llamada falla con 'not-found'.
final functionsProvider = Provider((_) =>
    FirebaseFunctions.instanceFor(region: 'europe-west3'));

/// Se inyecta en main(). Solo guarda datos pequeños del modo emergencia.
final sharedPrefsProvider = Provider<SharedPreferences>(
    (_) => throw UnimplementedError('override en main()'));

final connectivityProvider = Provider((_) => ConnectivityService());
final onlineProvider = StreamProvider<bool>(
    (ref) => ref.watch(connectivityProvider).onlineChanges);

final downloadManagerProvider = Provider((_) => DownloadManager(Dio()));

/// Notificaciones locales. El servicio se inicializa solo con el primer uso.
final notificationServiceProvider = Provider((_) => NotificationService());
