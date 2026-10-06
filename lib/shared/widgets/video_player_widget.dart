import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Reproductor con control opcional de avance.
/// - [lockForward]: se puede retroceder, pero nunca adelantar más allá de lo ya visto.
/// - [onCompleted]: se llama UNA sola vez, cuando el vídeo se ha visto entero.
/// - [localPath]: si existe el archivo, se reproduce sin red (modo emergencia).
/// - [forceAspectRatio]: si se indica (ej. 16/9), se usa ese ratio en lugar del del vídeo.
///
/// Incluye botón de pantalla completa. La vista grande se pinta en un [Overlay]
/// REUTILIZANDO el mismo [VideoPlayerController], no en otra pantalla: si se
/// recreara, el vídeo volvería a empezar y en el ejercicio diario se perdería el
/// bloqueo de avance (`_maxWatched`).
class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({
    super.key,
    this.url,
    this.localPath,
    this.lockForward = false,
    this.autoPlay = false,
    this.onCompleted,
    this.forceAspectRatio,
  });

  final String? url;
  final String? localPath;
  final bool lockForward;
  final bool autoPlay;
  final void Function(Duration total)? onCompleted;
  final double? forceAspectRatio;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  static const _tolerance = Duration(seconds: 2);

  late final VideoPlayerController _c;
  Duration _maxWatched = Duration.zero;
  bool _completed = false, _correcting = false, _failed = false;

  /// Entrada del overlay de pantalla completa. null = no está a pantalla completa.
  OverlayEntry? _fsEntry;

  bool get _isFullscreen => _fsEntry != null;

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
    // Si se cierra la pantalla (o el bottom sheet) estando a pantalla completa,
    // hay que quitar el overlay: si no, se quedaría flotando sobre toda la app.
    _removeFullscreen(restoreSystem: false);
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

  // ───────────────────────── Pantalla completa ─────────────────────────

  void _enterFullscreen() {
    if (_isFullscreen || !mounted) return;

    _fsEntry = OverlayEntry(
      builder: (_) => _FullscreenVideo(
        controller: _c,
        lockForward: widget.lockForward,
        onTogglePlay: _togglePlay,
        onBack10: _back10,
        clampSeek: _clampSeek,
        onExit: _exitFullscreen,
      ),
    );
    // rootOverlay: por encima de TODO, incluido el bottom sheet del detalle.
    Overlay.of(context, rootOverlay: true).insert(_fsEntry!);

    // Inmersivo y en horizontal, que es como se ve bien un vídeo.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Repinta el reproductor de dentro para que no pinte el vídeo DOS veces
    // (el de dentro queda detrás del overlay, que es opaco).
    setState(() {});
  }

  void _exitFullscreen() => _removeFullscreen();

  void _removeFullscreen({bool restoreSystem = true}) {
    _fsEntry?.remove();
    _fsEntry = null;

    if (restoreSystem) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      if (mounted) setState(() {});
    }
  }

  // ───────────────────────── Control ─────────────────────────

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
        child: Center(child: Text('No se pudo cargar el vídeo')),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _c,
      builder: (context, v, _) {
        if (v.hasError) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('No se pudo reproducir el vídeo')),
          );
        }
        if (!v.isInitialized) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ratio = widget.forceAspectRatio ??
            (v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: ratio,
              child: _VideoSurface(
                controller: _c,
                value: v,
                onTap: _togglePlay,
                // A pantalla completa el vídeo lo pinta el overlay.
                hideVideo: _isFullscreen,
              ),
            ),
            _ControlsBar(
              controller: _c,
              lockForward: widget.lockForward,
              onTogglePlay: _togglePlay,
              onBack10: _back10,
              clampSeek: _clampSeek,
              onFullscreen: _enterFullscreen,
            ),
            if (widget.lockForward)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: c.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Puedes retroceder, pero no adelantar.',
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// La superficie del vídeo: letterbox negro, toque para pausar y el icono de
/// play cuando está parado.
class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.controller,
    required this.value,
    required this.onTap,
    this.hideVideo = false,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final VoidCallback onTap;
  final bool hideVideo;

  @override
  Widget build(BuildContext context) {
    final v = value;

    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        // Letterbox si el vídeo no coincide con el ratio forzado.
        ColoredBox(
          color: Colors.black,
          child: hideVideo
              ? const SizedBox.expand()
              : FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: v.size.width,
                    height: v.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const SizedBox.expand(),
        ),
        if (!v.isPlaying)
          const IgnorePointer(
            child: Material(
              color: Colors.black38,
              shape: CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Barra de controles: play/pausa, retroceder 10 s, barra de progreso, tiempo y
/// botón de pantalla completa.
///
/// Tiene estado propio porque la barra de progreso necesita recordar dónde está
/// el dedo mientras se arrastra.
class _ControlsBar extends StatefulWidget {
  const _ControlsBar({
    required this.controller,
    required this.lockForward,
    required this.onTogglePlay,
    required this.onBack10,
    required this.clampSeek,
    this.onFullscreen,
    this.fullscreen = false,
  });

  final VideoPlayerController controller;
  final bool lockForward;
  final VoidCallback onTogglePlay;
  final VoidCallback onBack10;
  final double Function(double) clampSeek;

  /// Si se indica, se muestra el botón de pantalla completa.
  final VoidCallback? onFullscreen;

  /// En la vista grande: colores sobre negro.
  final bool fullscreen;

  @override
  State<_ControlsBar> createState() => _ControlsBarState();
}

class _ControlsBarState extends State<_ControlsBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = widget.fullscreen ? Colors.white : null;

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) {
        if (!v.isInitialized) return const SizedBox.shrink();

        final total = v.duration.inMilliseconds.toDouble();
        final pos = (_drag ?? v.position.inMilliseconds.toDouble())
            .clamp(0.0, total)
            .toDouble();

        return Row(
          children: [
            IconButton(
              tooltip: v.isPlaying ? 'Pausar' : 'Reproducir',
              color: fg,
              onPressed: widget.onTogglePlay,
              icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Retroceder 10 s',
              color: fg,
              onPressed: widget.onBack10,
              icon: const Icon(Icons.replay_10),
            ),
            Expanded(
              child: total <= 0
                  ? const SizedBox.shrink()
                  : Slider(
                      value: pos,
                      min: 0,
                      max: total,
                      onChanged: (x) =>
                          setState(() => _drag = widget.clampSeek(x)),
                      onChangeEnd: (x) {
                        final target = widget.clampSeek(x);
                        setState(() => _drag = null);
                        widget.controller
                            .seekTo(Duration(milliseconds: target.round()));
                      },
                    ),
            ),
            Text(
              '${_fmt(v.position)} / ${_fmt(v.duration)}',
              style: widget.fullscreen ? t.bodySmall?.copyWith(color: fg) : t.bodySmall,
            ),
            const SizedBox(width: 8),
            if (widget.onFullscreen != null)
              IconButton(
                tooltip: 'Ver a pantalla completa',
                onPressed: widget.onFullscreen,
                icon: const Icon(Icons.fullscreen),
              ),
          ],
        );
      },
    );
  }
}

/// Vista de pantalla completa: fondo negro, vídeo ajustado y controles encima.
class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({
    required this.controller,
    required this.lockForward,
    required this.onTogglePlay,
    required this.onBack10,
    required this.clampSeek,
    required this.onExit,
  });

  final VideoPlayerController controller;
  final bool lockForward;
  final VoidCallback onTogglePlay;
  final VoidCallback onBack10;
  final double Function(double) clampSeek;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, v, _) {
          if (!v.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final ratio = v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio;

          return Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: _VideoSurface(
                    controller: controller,
                    value: v,
                    onTap: onTogglePlay,
                  ),
                ),
              ),

              // Salir: arriba a la derecha.
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    tooltip: 'Salir de pantalla completa',
                    icon: const Icon(Icons.fullscreen_exit,
                        color: Colors.white, size: 32),
                    onPressed: onExit,
                  ),
                ),
              ),

              // Controles: abajo.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: _ControlsBar(
                      controller: controller,
                      lockForward: lockForward,
                      onTogglePlay: onTogglePlay,
                      onBack10: onBack10,
                      clampSeek: clampSeek,
                      fullscreen: true,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _fmt(Duration d) =>
    '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
