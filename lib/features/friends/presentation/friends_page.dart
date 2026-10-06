import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_view.dart';
import '../domain/friend.dart';
import '../friends_providers.dart';

/// Pantalla de Amigos: racha de cada uno y solicitud pendientes.
///
/// La racha de un amigo sale de `userStreaks/{uid}`, que escribe una Cloud
/// Function. Si no existe todavía, se indica en vez de fingir un 0.
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final pending = ref.watch(pendingRequestsProvider);
    final streaks = ref.watch(friendsStreaksProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(children: [
            Expanded(
              child: Text('Amigos',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton.filledTonal(
              tooltip: 'Gestionar amigos',
              icon: const Icon(Icons.group_add),
              onPressed: () => context.push('/friends/manage'),
            ),
          ]),

          // ── Solicitudes por aceptar ──
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Solicitudes',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final f in pending) _PendingTile(friend: f),
          ],

          const SizedBox(height: 20),
          Text('Tus amigos',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          AsyncView(
            value: friendsAsync,
            builder: (friends) {
              final accepted =
                  friends.where((f) => f.status == FriendStatus.accepted).toList();
              if (accepted.isEmpty) {
                return _EmptyFriends(
                  hasAnyLink: friends.isNotEmpty,
                  onManage: () => context.push('/friends/manage'),
                );
              }
              return Column(
                children: [
                  for (final f in accepted)
                    _FriendTile(friend: f, streak: streaks.valueOrNull?[f.uid]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────────── Vistas ─────────────

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.friend, required this.streak});

  final Friend friend;

  /// null = aún se está calculando; `hasData:false` = la Function no ha escrito.
  final ResolvedStreak? streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final s = streak;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _FriendAvatar(friend: friend),
          title: Text(friend.displayName.isEmpty ? 'Amigo' : friend.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_statusLine(s)),
          trailing: s == null || !s.hasData
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : s.isActive
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.orange, size: 22),
                      const SizedBox(width: 4),
                      Text('${s.streak}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ])
                  : Text('—', style: TextStyle(color: c.onSurfaceVariant)),
          onTap: () => _confirmRemove(context, ref, friend),
        ),
      ),
    );
  }

  /// Racha viva: "3 días de racha". Sin racha: cuánto lleva sin entrenar.
  String _statusLine(ResolvedStreak? s) {
    if (s == null) return 'Cargando…';
    if (!s.hasData) return 'Aún sin datos de racha';
    if (s.isActive) {
      final n = s.streak;
      return '$n ${n == 1 ? 'día' : 'días'} de racha';
    }
    final d = s.inactiveDays;
    if (d == null) return 'Nunca ha entrenado';
    if (d == 0) return 'Entrenó hoy';
    return 'Sin entrenar desde hace $d ${d == 1 ? 'día' : 'días'}';
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar a ${f.displayName}?'),
        content: const Text(
            'Se quitará de tu lista y de la suya. Tendréis que volver a '
            'enviaros un código para ser amigos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(removeFriendProvider)(f);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Amigo eliminado.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }
}

class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.friend});
  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            _FriendAvatar(friend: friend),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.displayName.isEmpty ? 'Amigo' : friend.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Quiere ser tu amigo',
                        style: TextStyle(fontSize: 12)),
                  ]),
            ),
            IconButton(
              tooltip: 'Rechazar',
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(removeFriendProvider)(friend),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () async {
                try {
                  await ref.read(acceptFriendProvider)(friend);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('No se pudo aceptar: $e')));
                  }
                }
              },
              child: const Text('Aceptar'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Avatar del amigo: usa su foto desnormalizada; si no, la inicial.
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});
  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const r = 24.0;
    final initial =
        friend.displayName.isEmpty ? '?' : friend.displayName[0].toUpperCase();
    final url = friend.photoUrl;

    return ClipOval(
      child: SizedBox(
        width: r * 2,
        height: r * 2,
        child: (url == null || url.isEmpty)
            ? Container(
                color: c.secondaryContainer,
                alignment: Alignment.center,
                child: Text(initial,
                    style: TextStyle(
                        color: c.onSecondaryContainer,
                        fontWeight: FontWeight.w800)))
            : Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: c.secondaryContainer,
                  alignment: Alignment.center,
                  child: Text(initial),
                )),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends({required this.hasAnyLink, required this.onManage});
  final bool hasAnyLink;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.group_outlined, size: 40, color: c.primary),
          const SizedBox(height: 10),
          Text(
            hasAnyLink
                ? 'Todavía no aceptas a nadie. En "Tus amigos" solo aparecen los '
                    'vínculos aceptados.'
                : 'Todavía no tienes amigos. Pide su código de invitación y '
                    'añádelos.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onManage,
            icon: const Icon(Icons.group_add),
            label: const Text('Gestionar amigos'),
          ),
        ]),
      ),
    );
  }
}

/// Rótulo reutilizable para el chip del código propio.
String inviteCodeHint(String code) => 'Tu código: $code';