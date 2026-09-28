import 'package:connectivity_plus/connectivity_plus.dart';

/// Nota: detecta interfaz de red, no garantiza alcance real a Firebase.
/// Por eso SyncService también tolera fallos y reintenta.
class ConnectivityService {
  ConnectivityService([Connectivity? c]) : _c = c ?? Connectivity();
  final Connectivity _c;

  static bool _isOnline(List<ConnectivityResult> r) => !r.contains(ConnectivityResult.none);

  Future<bool> get isOnline async => _isOnline(await _c.checkConnectivity());
  Stream<bool> get onlineChanges => _c.onConnectivityChanged.map(_isOnline).distinct();
}
