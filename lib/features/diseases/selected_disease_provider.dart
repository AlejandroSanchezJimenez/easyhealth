import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../auth/auth_providers.dart';

// Valor centinela de [selectedDiseaseIdProvider] que significa
/// "Entrenamiento general": no filtra por condición, se ve de todo.
////
/// Lleva guiones bajos porque los IDs de Firestore no los genera el cliente
/// de esta forma, así que no puede colisionear con una condición real.
const String kGeneralTrainingId = '__general__';

// Etiqueta del entrenamiento general tal como se ve en Explorar.
const String kGeneralTrainingLabel = 'Entrenamiento general';

// Lo que muestra Perfil cuando está activo el entrenamiento general.
const String kGeneralTrainingProfileLabel = 'Entrenamiento personal';

/// Estadios clínicos posibles para una enfermedad.
enum DiseaseStage {
  leve('Estadio I · Leve', 1),
  moderado('Estadio II · Moderado', 2),
  avanzado('Estadio III · Avanzado', 3),
  severo('Estadio IV · Severo', 4);

  final String label;
  final int level;
  const DiseaseStage(this.label, this.level);

  /// Convierte un valor guardado (nuevo o legado) en [DiseaseStage].
  static DiseaseStage? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in values) {
      if (s.label == raw || s.name == raw) return s;
    }
    return switch (raw.toLowerCase()) {
      'principiante' || 'leve' || 'estadio 1' || 'estadio i' => leve,
      'intermedio' || 'moderado' || 'estadio 2' || 'estadio ii' => moderado,
      'avanzado' || 'estadio 3' || 'estadio iii' => avanzado,
      'severo' || 'estadio 4' || 'estadio iv' => severo,
      _ => null,
    };
  }
}

/// ¿El contenido (estadio opcional) es compatible con el estadio del usuario?
///
/// Solo coincide si el contenido sirve para todos los estadios (`null`) o si es
/// exactamente del mismo estadio que el usuario.
bool matchesStage(String? contentStage, String? selectedStage) {
  final userStage = DiseaseStage.parse(selectedStage);
  final targetStage = DiseaseStage.parse(contentStage);
  if (userStage == null || targetStage == null) return true;
  return targetStage == userStage;
}

/// ¿Encaja el contenido con la condición y estadio seleccionados?
///
/// Concentra la regla del entrenamiento general para no repetirla: con
/// [kGeneralTrainingId] (o sin selección) encaja **todo** el contenido.
/// También considera el estadio si el usuario lo ha configurado.
bool matchesCondition(
  List<String> conditionIds,
  String? selected,
  String? selectedStage, [
  String? contentStage,
]) {
  // Si es entrenamiento general, todo cabe.
  if (selected == null || selected == kGeneralTrainingId) return true;

  // Filtrar por enfermedad: la enfermedad debe coincidir.
  if (!conditionIds.contains(selected)) return false;

  return matchesStage(contentStage, selectedStage);
}

/// Etapa elegida por el usuario. Se guarda POR CUENTA (uid),
/// así que al cambiar de cuenta no se hereda la selección de la anterior.
class SelectedStageNotifier extends StateNotifier<String?> {
  SelectedStageNotifier(this._p, this._uid)
      : super(_uid == null ? null : _p.getString(_keyForStage(_uid))) {
    // Limpia la clave global antigua que causaba la fuga entre cuentas.
    if (_p.containsKey(_legacyStageKey)) _p.remove(_legacyStageKey);
  }

  final SharedPreferences _p;
  final String? _uid;

  static const _legacyStageKey = 'selected_stage';
  static String _keyForStage(String uid) => 'selected_stage_$uid';

  void select(String? stage) {
    final uid = _uid;
    if (uid == null) return;
    state = stage;
    stage == null ? _p.remove(_keyForStage(uid)) : _p.setString(_keyForStage(uid), stage);
  }
}

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

/// Etapa de la enfermedad elegida por el usuario. Se guarda POR CUENTA (uid).
final selectedDiseaseStageProvider =
    StateNotifierProvider<SelectedStageNotifier, String?>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
  return SelectedStageNotifier(ref.watch(sharedPrefsProvider), uid);
});