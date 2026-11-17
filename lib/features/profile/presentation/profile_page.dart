import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// import '../../../app/theme/app_colors_ext.dart'; // solo lo usaba "Contenido sin conexión"
import '../../../core/profile/profile_photo_picker.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../diseases/diseases_providers.dart';
import '../../diseases/selected_disease_provider.dart';
// import '../../videos/videos_providers.dart'; // solo lo usaba "Contenido sin conexión'

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _roleLabel(UserRole r) => switch (r) {
        UserRole.teacher => 'Maestro',
        UserRole.admin => 'Administrador',
        UserRole.user => 'Usuario',
      };

  String _stageLabel(String? stage) =>
      DiseaseStage.parse(stage)?.label ?? 'Sin estadio';

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
    final currentStage = ref.watch(selectedDiseaseStageProvider);
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
                    // Mostrar etapa actual junto con la enfermedad
                    if (!isGeneral && selectedId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InfoChip(
                          label: _stageLabel(currentStage),
                          icon: Icons.crop_rounded,
                          color: c.primaryContainer,
                        ),
                      ),
                  ],
                ),
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
                subtitle: Text(
                  // Mostrar nombre de enfermedad y etapa
                  isGeneral
                      ? kGeneralTrainingProfileLabel
                      : diseaseName != null
                          ? '${diseaseName} ${_stageLabel(currentStage)}'
                          : 'Sin seleccionar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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

          // "Contenido sin conexión" desactivado: se queda para versiones
          // más adelantadas. Al reactivarlo, descomenta también los imports
          // `app_colors_ext.dart` y `videos_providers.dart` de arriba.
          // const _OfflineSection(),
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
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _confirmDeleteAccount(context, ref),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Borrar cuenta y datos'),
            style: TextButton.styleFrom(
              foregroundColor: c.error,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Kineo · v0.1.0',
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  // Métodos que ya existían en el archivo original
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de Kineo?'),
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

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }
}

// ───────────── Diálogo de borrado de cuenta ─────────────
/// Diálogo que pide la contraseña y borra la cuenta.
///
/// La contraseña NO es decorativa: se re-autentica con ella y eso la verifica
/// de verdad. Sin contraseña correcta, no se borra nada.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

// Estado interno del diálogo de borrado de cuenta.
class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Se captura ANTES de cualquier await: después, el diálogo puede estar
    // desmontado y `ScaffoldMessenger.of(context)` fallaría.
    final messenger = ScaffoldMessenger.of(context);

    // 1. Verificar la contraseña. Si falla, el error sale AQUÍ, en el diálogo.
    try {
      await ref.read(verifyPasswordProvider)(_pass.text);
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _busy = false;
        _error = e is StateError ? e.message.toString() : 'No se pudo verificar la contraseña.';
      });
      return;
    }

    // 2. Contraseña correcta: se cierra el diálogo y la app queda tapada por el
    //    loader, que se mantiene hasta que el router cambia al login. Así no se
    //    ve ni un frame de la pantalla normal.
    setState(() => _busy = true);
    if (context.mounted) Navigator.of(context).pop();

    try {
      await ref.read(deleteAccountProvider)();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo borrar la cuenta: $e'),
        duration: const Duration(seconds: 8),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Con el teclado abierto queda poco alto. `scrollable` hace que el
      // contenido se desplace en vez de aplastar los botones contra el campo.
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      icon: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 36),
      title: const Text('Borrar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrarán TU CUENTA y TODOS tus datos: historial, racha, '
            'progreso, amigos y foto de perfil. Esta acción no se puede '
            'deshacer.',
          ),
          const SizedBox(height: 16),
          const Text('Escribe tu contraseña para confirmar:'),
          const SizedBox(height: 8),
          TextField(
            controller: _pass,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Borrar'),
        ),
      ],
    );
  }
}