import '../../../core/utils/firestore_utils.dart';
import '../../../shared/models/content_status.dart';

/// Solo metadatos. El archivo vive en Firebase Storage.
class VideoMeta implements ContentEntity {
  const VideoMeta({
    required this.id,
    required this.storagePath,
    required this.downloadUrl,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.fileSize = 0,
    this.status = ContentStatus.draft,
    this.version = 1,
    this.updatedAt,
  });

  @override
  final String id;
  final String storagePath, downloadUrl;
  final String? thumbnailUrl;
  final int durationSeconds, fileSize;
  @override
  final ContentStatus status;
  @override
  final int version;
  final DateTime? updatedAt;

  factory VideoMeta.fromMap(String id, Map<String, dynamic> m) => VideoMeta(
        id: id,
        storagePath: m['storagePath'] as String? ?? '',
        downloadUrl: m['downloadUrl'] as String? ?? '',
        thumbnailUrl: m['thumbnailUrl'] as String?,
        durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
        fileSize: (m['fileSize'] as num?)?.toInt() ?? 0,
        status: ContentStatus.parse(m['status'] as String?),
        version: (m['version'] as num?)?.toInt() ?? 1,
        updatedAt: readDate(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'fileSize': fileSize,
        'status': status.name,
      };
}
