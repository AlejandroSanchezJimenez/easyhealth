import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

/// Enfermedad elegida por el usuario. Es solo una preferencia; se recuerda entre sesiones.
class SelectedDiseaseNotifier extends StateNotifier<String?> {
  SelectedDiseaseNotifier(this._p) : super(_p.getString(_key));
  final SharedPreferences _p;
  static const _key = 'selected_disease';

  void select(String? id) {
    state = id;
    id == null ? _p.remove(_key) : _p.setString(_key, id);
  }
}

final selectedDiseaseIdProvider =
    StateNotifierProvider<SelectedDiseaseNotifier, String?>(
        (ref) => SelectedDiseaseNotifier(ref.watch(sharedPrefsProvider)));
