import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors_ext.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../../auth/auth_providers.dart';
import '../../streak/streak_providers.dart';
import '../../videos/videos_providers.dart';
import '../domain/daily_pick.dart';

class DailyPlayerPage extends ConsumerStatefulWidget {
  const DailyPlayerPage({super.key, required this.pick});
  final DailyPick pick;

  @override
  ConsumerState<DailyPlayerPage> createState() => _DailyPlayerPageState();
}

class _DailyPlayerPageState extends ConsumerState<DailyPlayerPage> {
  /// Parte actual de la secuencia (0 si la clase tiene vídeo propio).
  int _index = 0;
  int _watchedSeconds = 0;
  bool _completed = false;

  List<String> get _videoIds => widget.pick.videoIds;
  String get _currentId => _videoIds[_index];
  bool get _isLast => _index >= _videoIds.length - 1;

  /// Si el vídeo está descargado, se reproduce el archivo local.
  String? _localPath(String videoId) {
    for (final w in ref.read(offlineLibraryProvider).all().values) {
      final p = w.videoPaths[videoId];
      if (p != null && File(p).existsSync()) return p;
    }
    return null;
  }

  /// Cada vídeo terminado suma y hace avanzar. Solo al terminar el ÚLTIMO se
  /// registra la sesión (racha): los anteriores no cuentan por sí solos.
  void _onPartCompleted(Duration total) {
    if (_completed || !mounted) return;
    setState(() {
      _watchedSeconds += total.inSeconds;
      if (_isLast) {
        _completed = true;
      } else {
        _index++;
      }
    });
    if (!_completed) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref.read(historyRepositoryProvider).completeSession(
          uid: user.uid,
          kind: widget.pick.kind,
          refId: widget.pick.id,
          seconds: _watchedSeconds,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final ok = context.appColors.success;
    final pick = widget.pick;
    final parts = pick.partNames.length == _videoIds.length ? pick.partNames : null;

    final video = ref.watch(videoByIdProvider(_currentId));
    final loadingVideos = ref.watch(videosProvider).isLoading;
    final local = _localPath(_currentId);

    final Widget player = (video == null && local == null)
        ? Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: loadingVideos
                ? const CircularProgressIndicator()
                : const Text('Vídeo no disponible'),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: c.surfaceContainerHighest,
              child: AppVideoPlayer(
                // La clave cambia de parte en parte: se recrea el reproductor y
                // arranca el siguiente vídeo automáticamente.
                key: ValueKey(_currentId),
                url: video?.downloadUrl,
                localPath: local,
                lockForward: true,
                autoPlay: true,
                onCompleted: _onPartCompleted,
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(pick.isWorkout ? 'Clase de hoy' : 'Ejercicio de hoy'),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(pick.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (pick.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(pick.description,
                style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          ],

          // Progreso de la secuencia: los vídeos se ven en orden y no se puede saltar.
          if (pick.isSequence) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / _videoIds.length,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_index + 1}/${_videoIds.length}',
                  style: t.labelLarge?.copyWith(color: c.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Esta clase no tiene vídeo propio: se reproducen en orden los vídeos de sus ejercicios.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: 16),
          player,
          const SizedBox(height: 16),

          // Lista de partes, marcando las ya vistas.
          if (parts != null) ...[
            Text('Ejercicios de la clase',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (var i = 0; i < parts.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i < _index || _completed
                      ? Icons.check_circle
                      : (i == _index ? Icons.play_circle : Icons.circle_outlined),
                  color: (i < _index || _completed) ? ok : c.onSurfaceVariant,
                ),
                title: Text(parts[i],
                    style: t.bodyMedium?.copyWith(
                      fontWeight: i == _index ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
            const SizedBox(height: 8),
          ],

          if (_completed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ok.withAlpha(35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ok.withAlpha(120)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.check_circle_rounded, color: ok),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        '¡Entrenamiento completado! Ya cuenta para tu racha de hoy.',
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver al inicio'),
                ),
              ]),
            )
          else
            Text(
              pick.isSequence
                  ? 'Mira todos los vídeos de la clase para que cuente en tu racha.'
                  : 'Mira el vídeo completo para que cuente en tu racha.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
        ]),
      ),
    );
  }
}
