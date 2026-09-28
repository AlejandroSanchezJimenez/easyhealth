import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/content_status.dart';

/// Acceso a Firestore (fuente principal). Sin red, Firestore sirve
/// lo que ya tenga en su caché interna; no hay BD local propia.
class ContentRemote<T extends ContentEntity> {
  ContentRemote(this._fs, this.collection, this.fromMap, this.toMap);
  final FirebaseFirestore _fs;
  final String collection;
  final T Function(String id, Map<String, dynamic> map) fromMap;
  final Map<String, dynamic> Function(T item) toMap;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection(collection);

  /// Usuarios: solo contenido publicado.
  Stream<List<T>> watchPublished() => _col
      .where('status', isEqualTo: ContentStatus.published.name)
      .snapshots()
      .map((s) => s.docs.map((d) => fromMap(d.id, d.data())).toList());

  /// Maestros: también borradores y archivados.
  Stream<List<T>> watchAll() =>
      _col.snapshots().map((s) => s.docs.map((d) => fromMap(d.id, d.data())).toList());

  /// El servidor incrementa `version` en cada guardado.
  Future<String> save(T item, {String? id, required String uid}) async {
    final ref = id == null ? _col.doc() : _col.doc(id);
    await ref.set({
      ...toMap(item),
      'version': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) ...{'createdAt': FieldValue.serverTimestamp(), 'createdBy': uid},
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> setStatus(String id, ContentStatus status) => _col.doc(id).update({
        'status': status.name,
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
