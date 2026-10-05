/// El entrenamiento del día: una clase de la enfermedad elegida.
/// Siempre tiene al menos un vídeo; si la clase no tiene vídeo propio, se
/// encadenan los vídeos de sus ejercicios.
class DailyPick {
  const DailyPick({
    required this.kind,
    required this.id,
    required this.name,
    required this.videoIds,
    this.partNames = const [],
    this.description = '',
    this.durationSeconds = 0,
  });

  /// 'workout' | 'exercise' (coincide con SessionRecord.kind)
  final String kind;
  final String id, name, description;

  /// Vídeos a reproducir **en orden**. Uno solo = la clase tiene vídeo propio.
  /// Varios = se concatenan los vídeos de sus ejercicios.
  final List<String> videoIds;

  /// Nombre de cada elemento de [videoIds] (para listar las partes).
  final List<String> partNames;

  final int durationSeconds;

  bool get isWorkout => kind == 'workout';

  /// true cuando no hay vídeo propio y se encadenan los de los ejercicios.
  bool get isSequence => videoIds.length > 1;

  String get key => '$kind:$id';
}
