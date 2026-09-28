import 'dart:io';
import 'package:dio/dio.dart';
import '../errors/failures.dart';

/// Descarga un archivo con reanudación (Range), progreso, cancelación
/// y validación de tamaño. Escribe en `.part` y renombra al terminar.
class DownloadManager {
  DownloadManager(this._dio);
  final Dio _dio;

  Future<File> downloadFile({
    required String url,
    required String savePath,
    int? expectedBytes,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final part = File('$savePath.part');
    await part.parent.create(recursive: true);
    var start = await part.exists() ? await part.length() : 0;

    final res = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: start > 0 ? {'range': 'bytes=$start-'} : null,
        validateStatus: (s) => s == 200 || s == 206,
      ),
    );

    final resumed = res.statusCode == 206;
    if (!resumed) start = 0;
    final len = int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '');
    final total = expectedBytes ?? (len == null ? -1 : start + len);

    final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = start;
    try {
      await for (final chunk in res.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }

    if (expectedBytes != null && await part.length() != expectedBytes) {
      await part.delete();
      throw DownloadValidationException('Tamaño inesperado en $url');
    }
    return part.rename(savePath);
  }

  Future<void> deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
