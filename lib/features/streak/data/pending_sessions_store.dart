import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_record.dart';

/// Red de seguridad: sesiones hechas que aún no están confirmadas en Firebase.
/// Se borran una a una en cuanto Firebase las acepta.
class PendingSessionsStore {
  PendingSessionsStore(this._p);
  final SharedPreferences _p;
  static const _key = 'pending_sessions';

  List<SessionRecord> all(String uid) => _read().where((s) => s.uid == uid).toList();
  Future<void> add(SessionRecord s) => _write([..._read(), s]);
  Future<void> remove(String id) => _write(_read().where((s) => s.id != id).toList());

  List<SessionRecord> _read() => (jsonDecode(_p.getString(_key) ?? '[]') as List)
      .map((e) => SessionRecord.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  Future<void> _write(List<SessionRecord> l) =>
      _p.setString(_key, jsonEncode(l.map((e) => e.toJson()).toList()));
}
