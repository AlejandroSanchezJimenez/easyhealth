class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DownloadValidationException extends AppFailure {
  const DownloadValidationException(super.message);
}

class InsufficientSpaceException extends AppFailure {
  const InsufficientSpaceException(super.message);
}
