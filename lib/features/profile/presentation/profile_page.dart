import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors_ext.dart';
import '../../../core/profile/profile_photo_picker.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../diseases/diseases_providers.dart';
import '../../diseases/selected_disease_provider.dart';
import '../../videos/videos_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _roleLabel(UserRole r) => switch (r) {
        UserRole.teacher => 'Maestro',
        UserRole.admin => 'Administrador',
        UserRole.user => 'Usuario',
      };

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de Kinea?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final display = user?.displayName?.trim() ?? '';
    final title = display.isNotEmpty
        ? display
        : (user?.email?.split('@').first ?? 'Usuario');

    final selectedId = ref.watch(selectedDiseaseIdProvider);
    final isGeneral = selectedId == kGeneralTrainingId;
    final diseaseName = isGeneral
        ? kGeneralTrainingProfileLabel
        : ref
                .watch(diseasesProvider)
                .valueOrNull
                ?.where((d) => d.id == selectedId)
                .firstOrNull
                ?.name;

    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // ── Tarjeta de usuario ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(28)),
              child: Row(children: [
                UserAvatar(
                  radius: 34,
                  showEditBadge: true,
                  onTap: () => pickAndUploadProfilePhoto(context, ref),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: t.titleLarge?.copyWith(
                                color: c.onPrimaryContainer,
                                fontWeight: FontWeight.w800)),
                        if (user?.email != null)
                          Text(user!.email!,
                              style: t.bodyMedium
                                  ?.copyWith(color: c.onPrimaryContainer)),
                        const SizedBox(height: 8),
                        InfoChip(
                            label: _roleLabel(user?.role ?? UserRole.user),
                            icon: Icons.verified_user_outlined,
                            color: c.onSurface),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Accesos ──
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.healing_rounded),
                  title: const Text('Mi condición'),
                  subtitle: Text(diseaseName ?? 'Sin seleccionar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/explore'),
                ),
                if (user?.role.canManageContent ?? false) ...[
                  Divider(height: 1, color: c.outlineVariant),
                  ListTile(
                    leading: const Icon(Icons.school_rounded),
                    title: const Text('Panel de maestro'),
                    subtitle:
                        const Text('Gestiona ejercicios, clases y vídeos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/teacher'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            const _OfflineSection(),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error,
                side: BorderSide(color: c.error.withAlpha(120)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('Kinea · v0.1.0',
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ),
          ]),
    );
  }
}

// ───────────── Contenido sin conexión ─────────────
class _OfflineSection extends ConsumerStatefulWidget {
  const _OfflineSection();
  @override
  ConsumerState<_OfflineSection> createState() => _OfflineSectionState();
}

class _OfflineSectionState extends ConsumerState<_OfflineSection> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final items = ref.watch(offlineLibraryProvider).all().values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final total = items.fold<int>(0, (s, w) => s + w.sizeBytes);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('Contenido sin conexión',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (items.isNotEmpty)
          InfoChip(label: formatBytes(total), icon: Icons.sd_storage_outlined),
      ]),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(Icons.download_for_offline_outlined,
                  color: c.outline, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                    'Aún no has descargado ninguna clase. Descárgalas para usarlas sin Internet.',
                    style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              ),
            ]),
          ),
        )
      else
        Card(
          child: Column(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.outlineVariant),
              ListTile(
                leading: Icon(Icons.download_done_rounded,
                    color: context.appColors.success),
                title: Text(items[i].workout.name),
                subtitle: Text(
                    '${items[i].exerciseMaps.length} ejercicios · ${formatBytes(items[i].sizeBytes)}'),
                trailing: IconButton(
                  tooltip: 'Eliminar descarga',
                  icon: Icon(Icons.delete_outline, color: c.error),
                  onPressed: () async {
                    await ref
                        .read(workoutDownloaderProvider)
                        .remove(items[i].workoutId);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ]),
        ),
    ]);
  }
}
