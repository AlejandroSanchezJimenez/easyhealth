import 'dart:async';

import '../network/connectivity_service.dart';

/// Al recuperar conexión ejecuta `onReconnect` (p. ej. subir sesiones pendientes).
class SyncService {
  SyncService(this._net, this._onReconnect);
  final ConnectivityService _net;
  final Future<void> Function() _onReconnect;
  StreamSubscription<bool>? _sub;

  void start() {
    _sub = _net.onlineChanges.where((o) => o).listen((_) => _onReconnect());
    _onReconnect(); // por si hay pendientes de una sesión anterior
  }

  void dispose() => _sub?.cancel();
}
