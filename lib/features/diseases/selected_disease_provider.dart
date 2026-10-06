import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../auth/auth_providers.dart';

/// Valor centinela de [selectedDiseaseIdProvider] que significa
/// "Entrenamiento general": no filtra por condición, se ve de todo.
///
/// Lleva guiones bajos porque los IDs de Firestore no los genera el cliente
/// de esta forma, así que no puede colisionear con una condición real.
const String kGeneralTrainingId = '__general__';

/// Etiqueta del entrenamiento general tal como se ve en Explorar.
const String kGeneralTrainingLabel = 'Entrenamiento general';

/// Lo que muestra Perfil cuando está activo el entrenamiento general.
const String kGeneralTrainingProfileLabel = 'Entrenamiento personal';

/// ¿Encaja el contenido con la condición seleccionada?
///
/// Concentra la regla del entrenamiento general para no repetirla: con
/// [kGeneralTrainingId] (o sin selección) encaja **todo** el contenido.
bool matchesCondition(List<String> conditionIds, String? selected) =>
    selected == null ||
    selected == kGeneralTrainingId ||
    conditionIds.contains(selected);

/// Condición elegida por el usuario. Se guarda POR CUENTA (uid),
/// así que al cambiar de cuenta no se hereda la selección de la anterior.
class SelectedDiseaseNotifier extends StateNotifier<String?> {
  SelectedDiseaseNotifier(this._p, this._uid)
      : super(_uid == null ? null : _p.getString(_keyFor(_uid))) {
    // Limpia la clave global antigua que causaba la fuga entre cuentas.
    if (_p.containsKey(_legacyKey)) _p.remove(_legacyKey);
  }

  final SharedPreferences _p;
  final String? _uid;

  static const _legacyKey = 'selected_disease';
  static String _keyFor(String uid) => 'selected_disease_$uid';

  void select(String? id) {
    final uid = _uid;
    if (uid == null) return;
    state = id;
    id == null ? _p.remove(_keyFor(uid)) : _p.setString(_keyFor(uid), id);
  }
}

final selectedDiseaseIdProvider =
    StateNotifierProvider<SelectedDiseaseNotifier, String?>((ref) {
  // Solo se recrea cuando cambia el uid (no en cada refresco de token).
  final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
  return SelectedDiseaseNotifier(ref.watch(sharedPrefsProvider), uid);
});
