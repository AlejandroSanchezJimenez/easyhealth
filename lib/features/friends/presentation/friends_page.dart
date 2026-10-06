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
    final sent = ref.watch(sentRequestsProvider);
    final streaks = ref.watch(friendsStreaksProvider);
    final profiles = ref.watch(friendsProfilesProvider);

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
                  _FriendsTab(
                      friends: friendsAsync,
                      streaks: streaks,
                      profiles: profiles),
                  _InvitesTab(pending: pending, sent: sent),
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
  const _FriendsTab(
      {required this.friends, required this.streaks, required this.profiles});

  final AsyncValue<List<Friend>> friends;
  final AsyncValue<Map<String, ResolvedStreak>> streaks;
  final AsyncValue<Map<String, PublicProfile>> profiles;

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
              _FriendTile(
                friend: f,
                streak: streaks.valueOrNull?[f.uid],
                profile: profiles.valueOrNull?[f.uid],
              ),
          ],
        );
      },
    );
  }
}

// ───────────── Pestaña: Invitaciones ─────────────

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({required this.pending, required this.sent});

  /// Recibidas: me las enviaron a mí y esperan mi respuesta.
  final List<Friend> pending;

  /// Enviadas por mí, aún sin aceptar. No cuentan para el badge.
  final List<Friend> sent;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty && sent.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: const [_EmptyInvites()],
      );
    }

    // Solo hacen falta cabeceras cuando conviven los dos tipos; si solo hay
    // uno, el nombre de la pestaña ya lo dice todo.
    final showHeaders = pending.isNotEmpty && sent.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        if (pending.isNotEmpty) ...[
          if (showHeaders) const _SectionLabel('Recibidas'),
          for (final f in pending) _PendingTile(friend: f),
        ],
        if (sent.isNotEmpty) ...[
          if (showHeaders) ...[
            const SizedBox(height: 12),
            const _SectionLabel('Enviadas'),
          ],
          for (final f in sent) _SentTile(friend: f),
        ],
      ],
    );
  }
}

/// Cabecera de sección dentro de una pestaña.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

// ───────────── Vistas ─────────────

class _FriendTile extends ConsumerWidget {
  const _FriendTile(
      {required this.friend, required this.streak, this.profile});

  final Friend friend;

  /// null = aún se está calculando; `hasData:false` = la Function no ha escrito.
  final ResolvedStreak? streak;

  /// Perfil público fresco (foto/nombre). Puede no haber llegado todavía.
  final PublicProfile? profile;

  /// Nombre a mostrar: el fresco si lo hay; si no, el copiado en el vínculo.
  String get _name {
    final n = profile?.displayName;
    if (n != null && n.isNotEmpty) return n;
    return friend.displayName.isEmpty ? 'Amigo' : friend.displayName;
  }

  /// Foto a mostrar: la fresca si la hay; si no, la copiada en el vínculo.
  String? get _photo {
    final p = profile?.photoUrl;
    if (p != null && p.isNotEmpty) return p;
    return friend.photoUrl;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _FriendAvatar(name: _name, photoUrl: _photo),
          title:
              Text(_name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_statusLine(streak)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _streakBadge(context, streak),
            // Papelera explícita: que se vea que ahí se borra.
            IconButton(
              tooltip: 'Eliminar amigo',
              icon: Icon(Icons.delete_outline, color: c.error),
              onPressed: () => _confirmRemove(context, ref, friend),
            ),
          ]),
        ),
      ),
    );
  }

  /// Indicador de racha.
  ///
  /// OJO: `hasData:false` significa "la Cloud Function aún no ha escrito el
  /// resumen", NO "cargando". Si aquí se pintara un spinner, giraría para
  /// siempre, porque ese resumen puede no llegar nunca.
  Widget _streakBadge(BuildContext context, ResolvedStreak? s) {
    final c = Theme.of(context).colorScheme;

    if (s == null) {
      // Esto SÍ es cargando: la consulta está en vuelo.
      return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (!s.hasData) {
      return Tooltip(
        message: 'Sin datos de racha todavía',
        child: Text('—', style: TextStyle(color: c.onSurfaceVariant)),
      );
    }
    if (s.isActive) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded,
            color: Colors.orange, size: 22),
        const SizedBox(width: 4),
        Text('${s.streak}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ]);
    }
    return Text('—', style: TextStyle(color: c.onSurfaceVariant));
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
            _FriendAvatar(
                name: f.displayName, photoUrl: f.photoUrl),
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

/// Una solicitud que YO envié y sigue pendiente. Se puede cancelar.
class _SentTile extends ConsumerStatefulWidget {
  const _SentTile({required this.friend});
  final Friend friend;

  @override
  ConsumerState<_SentTile> createState() => _SentTileState();
}

class _SentTileState extends ConsumerState<_SentTile> {
  bool _busy = false;

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(removeFriendProvider)(widget.friend);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud cancelada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    final name = f.displayName.isEmpty ? 'Alguien' : f.displayName;
    final c = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: _FriendAvatar(name: f.displayName, photoUrl: f.photoUrl),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Solicitud enviada, sin aceptar'),
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _cancel,
                  child: Text('Cancelar', style: TextStyle(color: c.error)),
                ),
        ),
      ),
    );
  }
}

/// Avatar del amigo: su foto si la tiene; si no, la inicial.
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const r = 24.0;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final url = photoUrl;

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
            'No tienes invitaciones pendientes. Aquí aparecen tanto las que te '
            'envían (para aceptarlas o rechazarlas) como las que envías tú '
            '(para cancelarlas si te arrepientes).',
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
