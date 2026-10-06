import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_view.dart';
import '../domain/friend.dart';
import '../friends_providers.dart';

/// Pantalla de Amigos, con dos pestañas:
///
///   - **Amigos**: los vínculos ACEPTADOS, con su racha.
///   - **Invitaciones**: las solicitudes que me han enviado. Lleva un badge
///     con el número de pendientes y botones de aceptar/rechazar.
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

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(children: [
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
            ),
            const SizedBox(height: 4),
            TabBar(
              tabs: [
                const Tab(text: 'Amigos'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Invitaciones'),
                      // El número solo aparece si hay alguna pendiente.
                      if (pending.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Badge(label: Text('${pending.length}')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _FriendsTab(friends: friendsAsync, streaks: streaks),
                  _InvitesTab(pending: pending),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────── Pestaña: Amigos ─────────────

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.friends, required this.streaks});

  final AsyncValue<List<Friend>> friends;
  final AsyncValue<Map<String, ResolvedStreak>> streaks;

  @override
  Widget build(BuildContext context) {
    return AsyncView(
      value: friends,
      builder: (list) {
        final accepted =
            list.where((f) => f.status == FriendStatus.accepted).toList();

        if (accepted.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              _EmptyFriends(
                hasAnyLink: list.isNotEmpty,
                onManage: () => context.push('/friends/manage'),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            for (final f in accepted)
              _FriendTile(friend: f, streak: streaks.valueOrNull?[f.uid]),
          ],
        );
      },
    );
  }
}

// ───────────── Pestaña: Invitaciones ─────────────

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({required this.pending});
  final List<Friend> pending;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: const [_EmptyInvites()],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        for (final f in pending) _PendingTile(friend: f),
      ],
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
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

class _PendingTile extends ConsumerStatefulWidget {
  const _PendingTile({required this.friend});
  final Friend friend;

  @override
  ConsumerState<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends ConsumerState<_PendingTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String errorLabel) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$errorLabel: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    final name = f.displayName.isEmpty ? 'Alguien' : f.displayName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            _FriendAvatar(friend: f),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Quiere ser tu amigo',
                        style: TextStyle(fontSize: 12)),
                  ]),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              IconButton(
                tooltip: 'Rechazar',
                icon: const Icon(Icons.close),
                onPressed: () => _run(
                    () => ref.read(removeFriendProvider)(f), 'No se pudo rechazar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _run(
                    () => ref.read(acceptFriendProvider)(f), 'No se pudo aceptar'),
                child: const Text('Aceptar'),
              ),
            ],
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
                ? 'Todavía no aceptas a nadie. Mira en "Invitaciones": puede que '
                    'alguien te haya añadido.'
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

class _EmptyInvites extends StatelessWidget {
  const _EmptyInvites();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.mark_email_unread_outlined, size: 40, color: c.primary),
          const SizedBox(height: 10),
          Text(
            'No tienes invitaciones pendientes. Cuando alguien te añada con tu '
            'código, aparecerá aquí para que la aceptes o la rechaces.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: c.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}
