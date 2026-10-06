import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_providers.dart';
import '../friends_providers.dart';

/// Gestionar amigos: ver mi código para compartirlo y añadir por código.
class ManageFriendsPage extends ConsumerWidget {
  const ManageFriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeAsync = ref.watch(inviteCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar amigos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Mi código de invitación',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Compártelo para que tus amigos puedan añadirte.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          codeAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator())),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No se pudo generar tu código: $e'),
              ),
            ),
            data: (code) => code == null
                ? const SizedBox.shrink()
                : _CodeBox(code: code),
          ),
          const SizedBox(height: 28),
          Text('Añadir a un amigo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Pide su código y añádelo. Lo aceptó dentro de la app.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const _AddByCode(),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(
            code,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: c.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado.')));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Compártelo con $code')),
              ),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Compartir'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _AddByCode extends ConsumerStatefulWidget {
  const _AddByCode();
  @override
  ConsumerState<_AddByCode> createState() => _AddByCodeState();
}

class _AddByCodeState extends ConsumerState<_AddByCode> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    setState(() => _busy = true);
    try {
      final msg = await ref.read(addFriendProvider)(_code.text);
      _code.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _code,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        maxLength: 6,
        onSubmitted: (_) => _busy ? null : _submit(),
        decoration: const InputDecoration(
          labelText: 'Código de tu amigo',
          hintText: 'ABC123',
          counterText: '',
          prefixIcon: Icon(Icons.vpn_key_outlined),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _submit,
        icon: _busy
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.group_add),
        label: Text(_busy ? 'Enviando…' : 'Añadir'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ]);
  }
}