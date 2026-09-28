enum ContentStatus {
  draft,
  published,
  archived;

  static ContentStatus parse(String? v) =>
      ContentStatus.values.firstWhere((e) => e.name == v, orElse: () => ContentStatus.draft);
}

/// Contrato común del contenido versionado.
abstract interface class ContentEntity {
  String get id;
  int get version;
  ContentStatus get status;
}
