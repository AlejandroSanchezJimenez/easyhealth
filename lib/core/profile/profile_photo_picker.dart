import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';

/// Abre la galería para elegir una foto de perfil.
///
/// Permite quitar la foto actual. Avisa por SnackBar si algo falla y muestra un
/// diálogo de progreso durante la subida.
Future<void> pickAndUploadProfilePhoto(BuildContext context, WidgetRef ref) async {
  final hasPhoto = ref.read(userPhotoUrlProvider) != null;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Elegir de la galería'),
          onTap: () => Navigator.pop(ctx, 'pick'),
        ),
        if (hasPhoto)
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error),
            title: Text('Quitar la foto',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );

  if (action == null || !context.mounted) return;

  if (action == 'remove') {
    _showProgress(context, 'Quitando la foto…');
    try {
      await ref.read(removeProfilePhotoProvider)();
      if (context.mounted) _snack(context, 'Foto eliminada.');
    } catch (e) {
      if (context.mounted) _snack(context, 'No se pudo quitar: $e');
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    return;
  }

  // 'pick'
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    // Comprime de lado Android; en iOS el plugin ya entrega una copia.
    withData: false,
  );
  final path = result?.files.single.path;
  if (path == null || !context.mounted) return;

  final file = File(path);
  final sizeMb = file.lengthSync() / (1024 * 1024);
  if (sizeMb > 15) {
    _snack(context, 'La imagen es demasiado grande (${sizeMb.toStringAsFixed(1)} MB). '
        'Elige una de menos de 15 MB.');
    return;
  }

  _showProgress(context, 'Subiendo foto…');
  try {
    await ref.read(uploadProfilePhotoProvider)(file);
    if (context.mounted) _snack(context, 'Foto actualizada.');
  } catch (e) {
    if (context.mounted) _snack(context, 'No se pudo subir la foto: $e');
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Diálogo modal de progreso, no dismissable mientras dura la operación.
/// Se cierra con `Navigator.pop` sobre el rootNavigator.
void _showProgress(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ]),
      ),
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}