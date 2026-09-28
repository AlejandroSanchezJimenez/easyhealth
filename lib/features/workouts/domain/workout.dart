import '../../../core/utils/firestore_utils.dart';
import '../../../shared/models/content_status.dart';

/// Un ejercicio dentro de una clase, con tiempo/repeticiones opcionales.
class WorkoutItem {
  const WorkoutItem({required this.exerciseId, this.seconds, this.reps});
  final String exerciseId;
  final int? seconds, reps;

  factory WorkoutItem.fromMap(Map<String, dynamic> m) => WorkoutItem(
        exerciseId: m['exerciseId'] as String,
        seconds: (m['seconds'] as num?)?.toInt(),
        reps: (m['reps'] as num?)?.toInt(),
      );
  Map<String, dynamic> toMap() => {'exerciseId': exerciseId, 'seconds': seconds, 'reps': reps};
}

class Workout implements ContentEntity {
  const Workout({
    required this.id,
    required this.name,
    this.description = '',
    this.durationSeconds = 0,
    this.difficulty = 1,
    this.thumbnailUrl,
    this.videoId,
    this.items = const [], // el orden de la lista ES el orden de la clase
    this.diseaseIds = const [],
    this.status = ContentStatus.draft,
    this.version = 1,
    this.updatedAt,
  });

  @override
  final String id;
  final String name, description;
  final int durationSeconds, difficulty;
  final String? thumbnailUrl, videoId;
  final List<WorkoutItem> items;
  final List<String> diseaseIds;
  @override
  final ContentStatus status;
  @override
  final int version;
  final DateTime? updatedAt;

  List<String> get exerciseIds => items.map((e) => e.exerciseId).toList();

  factory Workout.fromMap(String id, Map<String, dynamic> m) => Workout(
        id: id,
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
        difficulty: (m['difficulty'] as num?)?.toInt() ?? 1,
        thumbnailUrl: m['thumbnailUrl'] as String?,
        videoId: m['videoId'] as String?,
        items: ((m['items'] as List?) ?? const [])
            .map((e) => WorkoutItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        diseaseIds: readStrings(m['diseaseIds']),
        status: ContentStatus.parse(m['status'] as String?),
        version: (m['version'] as num?)?.toInt() ?? 1,
        updatedAt: readDate(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'durationSeconds': durationSeconds,
        'difficulty': difficulty,
        'thumbnailUrl': thumbnailUrl,
        'videoId': videoId,
        'items': items.map((e) => e.toMap()).toList(),
        'exerciseIds': exerciseIds, // redundante: permite consultas array-contains
        'diseaseIds': diseaseIds,
        'status': status.name,
      };
}
