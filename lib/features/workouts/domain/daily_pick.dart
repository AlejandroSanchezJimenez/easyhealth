/// El entrenamiento del día: un ejercicio O una clase, siempre con vídeo.
class DailyPick {
  const DailyPick({
    required this.kind,
    required this.id,
    required this.name,
    required this.videoId,
    this.description = '',
    this.durationSeconds = 0,
  });

  /// 'exercise' | 'workout' (coincide con SessionRecord.kind)
  final String kind;
  final String id, name, description, videoId;
  final int durationSeconds;

  bool get isWorkout => kind == 'workout';
  String get key => '$kind:$id';
}
