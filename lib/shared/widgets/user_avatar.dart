import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';

/// Avatar del usuario.
///
/// Muestra la foto de `users/{uid}.photoUrl` si existe y, mientras no haya
/// foto (o si falla la carga), la inicial del nombre — que es lo que se ve
/// hoy. Al pulsar [onTap] se abre el selector de imagen.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    this.radius = 34,
    this.onTap,
    this.showEditBadge = false,
  });

  final double radius;
  final VoidCallback? onTap;

  /// Dibuja un candado pequeño abajo a la derecha para Invite a "cambiar foto".
  final bool showEditBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final photoUrl = ref.watch(userPhotoUrlProvider);
    final user = ref.watch(currentUserProvider);
    final display = user?.displayName?.trim() ?? '';
    final name = display.isNotEmpty
        ? display
        : (user?.email?.split('@').first ?? '');
    final initial =
        name.isEmpty ? '?' : name[0].toUpperCase();

    final avatar = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: photoUrl == null
            ? _Initial(initial: initial)
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initial(initial: initial),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _Initial(initial: initial),
              ),
      ),
    );

    final decorated = showEditBadge
        ? Stack(clipBehavior: Clip.none, children: [
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: Icon(Icons.photo_camera_outlined,
                    size: radius * 0.32, color: c.onPrimary),
              ),
            ),
          ])
        : avatar;

    if (onTap == null) return decorated;
    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: decorated,
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      color: c.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: c.onPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}