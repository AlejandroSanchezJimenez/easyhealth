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
  bool _completed = false;

  /// Si la clase está descargada, se reproduce el archivo local.
  String? _localPath() {
    for (final w in ref.read(offlineLibraryProvider).all().values) {
      final p = w.videoPaths[widget.pick.videoId];
      if (p != null && File(p).existsSync()) return p;
    }
    return null;
  }

  /// El vídeo se ha visto entero: AQUÍ y solo aquí se registra la sesión (racha).
  Future<void> _onCompleted(Duration total) async {
    if (_completed || !mounted) return;
    setState(() => _completed = true);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(historyRepositoryProvider).completeSession(
          uid: user.uid,
          kind: widget.pick.kind,
          refId: widget.pick.id,
          seconds: total.inSeconds,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final ok = context.appColors.success;
    final pick = widget.pick;

    final video = ref.watch(videoByIdProvider(pick.videoId));
    final loadingVideos = ref.watch(videosProvider).isLoading;
    final local = _localPath();

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
                key: ValueKey(pick.videoId),
                url: video?.downloadUrl,
                localPath: local,
                lockForward: true,
                autoPlay: true,
                onCompleted: _onCompleted,
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
          title: Text(pick.isWorkout ? 'Clase de hoy' : 'Ejercicio de hoy')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(pick.name,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (pick.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(pick.description,
                style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          ],
          const SizedBox(height: 16),
          player,
          const SizedBox(height: 16),
          if (_completed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ok.withAlpha(35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ok.withAlpha(120)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.check_circle_rounded, color: ok),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            '¡Entrenamiento completado! Ya cuenta para tu racha de hoy.',
                            style: t.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
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
            Text('Mira el vídeo completo para que cuente en tu racha.',
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
