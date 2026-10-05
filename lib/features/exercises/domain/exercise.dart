import '../../../core/utils/firestore_utils.dart';
import '../../../shared/models/content_status.dart';

class Exercise implements ContentEntity {
  const Exercise({
    required this.id,
    required this.name,
    this.description = '',
    this.instructions = const [],
    this.durationSeconds = 0,
    this.difficulty = 1,
    this.sets = 0,
    this.reps = 0,
    this.diseaseIds = const [],
    this.videoId,
    this.thumbnailUrl,
    this.equipment = const [],
    this.benefits = const [],
    this.precautions = const [],
    this.contraindications = const [],
    this.status = ContentStatus.draft,
    this.version = 1,
    this.updatedAt,
  });

  @override
  final String id;
  final String name, description;
  final List<String> instructions, diseaseIds, equipment, benefits, precautions, contraindications;
  final int durationSeconds, difficulty, sets, reps;
  final String? videoId, thumbnailUrl;
  @override
  final ContentStatus status;
  @override
  final int version;
  final DateTime? updatedAt;

  factory Exercise.fromMap(String id, Map<String, dynamic> m) => Exercise(
        id: id,
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        instructions: readStrings(m['instructions']),
        durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
        difficulty: (m['difficulty'] as num?)?.toInt() ?? 1,
        sets: (m['sets'] as num?)?.toInt() ?? 0,
        reps: (m['reps'] as num?)?.toInt() ?? 0,
        diseaseIds: readStrings(m['diseaseIds']),
        videoId: m['videoId'] as String?,
        thumbnailUrl: m['thumbnailUrl'] as String?,
        equipment: readStrings(m['equipment']),
        benefits: readStrings(m['benefits']),
        precautions: readStrings(m['precautions']),
        contraindications: readStrings(m['contraindications']),
        status: ContentStatus.parse(m['status'] as String?),
        version: (m['version'] as num?)?.toInt() ?? 1,
        updatedAt: readDate(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'instructions': instructions,
        'durationSeconds': durationSeconds,
        'difficulty': difficulty,
        'sets': sets,
        'reps': reps,
        'diseaseIds': diseaseIds,
        'videoId': videoId,
        'thumbnailUrl': thumbnailUrl,
        'equipment': equipment,
        'benefits': benefits,
        'precautions': precautions,
        'contraindications': contraindications,
        'status': status.name,
      };
}
