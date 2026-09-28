import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reproductor con control opcional de avance.
/// - [lockForward]: se puede retroceder, pero nunca adelantar más allá de lo ya visto.
/// - [onCompleted]: se llama UNA sola vez, cuando el vídeo se ha visto entero.
/// - [localPath]: si existe el archivo, se reproduce sin red (modo emergencia).
class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({
    super.key,
    this.url,
    this.localPath,
    this.lockForward = false,
    this.autoPlay = false,
    this.onCompleted,
  });

  final String? url;
  final String? localPath;
  final bool lockForward;
  final bool autoPlay;
  final void Function(Duration total)? onCompleted;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  static const _tolerance = Duration(seconds: 2);

  late final VideoPlayerController _c;
  Duration _maxWatched = Duration.zero;
  bool _completed = false, _correcting = false, _failed = false;
  double? _drag; // ms mientras se arrastra el slider

  @override
  void initState() {
    super.initState();
    final local = widget.localPath;
    _c = (local != null && File(local).existsSync())
        ? VideoPlayerController.file(File(local))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url ?? ''));
    _c.addListener(_onTick);
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      if (widget.autoPlay) _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  void _onTick() {
    final v = _c.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;

    if (widget.lockForward) {
      // Salto hacia delante (no debería ocurrir): se devuelve al punto visto.
      if (v.position > _maxWatched + _tolerance) {
        if (!_correcting) {
          _correcting = true;
          _c.seekTo(_maxWatched).whenComplete(() => _correcting = false);
        }
        return;
      }
      if (v.position > _maxWatched) _maxWatched = v.position;
    }

    final atEnd = v.position >= v.duration - const Duration(milliseconds: 300);
    final watchedAll =
        !widget.lockForward || _maxWatched >= v.duration - _tolerance;
    if (!_completed && atEnd && watchedAll) {
      _completed = true;
      widget.onCompleted?.call(v.duration);
    }
  }

  double _clampSeek(double ms) => widget.lockForward
      ? ms.clamp(0.0, _maxWatched.inMilliseconds.toDouble()).toDouble()
      : ms;

  void _togglePlay() => _c.value.isPlaying ? _c.pause() : _c.play();

  void _back10() {
    final target = _c.value.position - const Duration(seconds: 10);
    _c.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    if (_failed) {
      return const SizedBox(
          height: 180,
          child: Center(child: Text('No se pudo cargar el vídeo')));
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _c,
      builder: (context, v, _) {
        if (v.hasError) {
          return const SizedBox(
              height: 180,
              child: Center(child: Text('No se pudo reproducir el vídeo')));
        }
        if (!v.isInitialized) {
          return const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()));
        }

        final total = v.duration.inMilliseconds.toDouble();
        final pos = (_drag ?? v.position.inMilliseconds.toDouble())
            .clamp(0.0, total)
            .toDouble();

        return Column(mainAxisSize: MainAxisSize.min, children: [
          AspectRatio(
            aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
            child: Stack(alignment: Alignment.center, children: [
              VideoPlayer(_c),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: const SizedBox.expand(),
              ),
              if (!v.isPlaying)
                IgnorePointer(
                  child: Material(
                    color: Colors.black38,
                    shape: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child:
                          Icon(Icons.play_arrow, color: Colors.white, size: 42),
                    ),
                  ),
                ),
            ]),
          ),
          Row(children: [
            IconButton(
              tooltip: v.isPlaying ? 'Pausar' : 'Reproducir',
              onPressed: _togglePlay,
              icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Retroceder 10 s',
              onPressed: _back10,
              icon: const Icon(Icons.replay_10),
            ),
            Expanded(
              child: total <= 0
                  ? const SizedBox.shrink()
                  : Slider(
                      value: pos,
                      min: 0,
                      max: total,
                      onChanged: (x) => setState(() => _drag = _clampSeek(x)),
                      onChangeEnd: (x) {
                        final target = _clampSeek(x);
                        setState(() => _drag = null);
                        _c.seekTo(Duration(milliseconds: target.round()));
                      },
                    ),
            ),
            Text('${_fmt(v.position)} / ${_fmt(v.duration)}',
                style: t.bodySmall),
            const SizedBox(width: 8),
          ]),
          if (widget.lockForward)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 14, color: c.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Puedes retroceder, pero no adelantar.',
                    style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ]),
            ),
        ]);
      },
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}
