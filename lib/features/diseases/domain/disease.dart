import '../../../core/utils/firestore_utils.dart';
import '../../../shared/models/content_status.dart';

class Disease implements ContentEntity {
  const Disease({
    required this.id,
    required this.name,
    this.description = '',
    this.shortDescription = '',
    this.imageUrl,
    this.icon,
    this.category,
    this.status = ContentStatus.draft,
    this.version = 1,
    this.updatedAt,
  });

  @override
  final String id;
  final String name, description, shortDescription;
  final String? imageUrl, icon, category;
  @override
  final ContentStatus status;
  @override
  final int version;
  final DateTime? updatedAt;

  factory Disease.fromMap(String id, Map<String, dynamic> m) => Disease(
        id: id,
        name: m['name'] as String? ?? '',
        description: m['description'] as String? ?? '',
        shortDescription: m['shortDescription'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        icon: m['icon'] as String?,
        category: m['category'] as String?,
        status: ContentStatus.parse(m['status'] as String?),
        version: (m['version'] as num?)?.toInt() ?? 1,
        updatedAt: readDate(m['updatedAt']),
      );

  /// Sin version/fechas: las gestiona el servidor.
  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'shortDescription': shortDescription,
        'imageUrl': imageUrl,
        'icon': icon,
        'category': category,
        'status': status.name,
      };
}
