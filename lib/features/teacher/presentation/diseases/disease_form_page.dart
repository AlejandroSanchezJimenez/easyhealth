import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/content_status.dart';
import '../../../auth/auth_providers.dart';
import '../../../diseases/diseases_providers.dart';
import '../../../diseases/domain/disease.dart';

class DiseaseFormPage extends ConsumerStatefulWidget {
  const DiseaseFormPage({super.key, this.id});
  final String? id; // null = crear

  @override
  ConsumerState<DiseaseFormPage> createState() => _DiseaseFormPageState();
}

class _DiseaseFormPageState extends ConsumerState<DiseaseFormPage> {
  final _name = TextEditingController();
  final _short = TextEditingController();
  final _desc = TextEditingController();
  final _category = TextEditingController();
  final _icon = TextEditingController();
  bool _busy = false;
  String? _error;
  Disease? _existing;

  bool get _isNew => widget.id == null || widget.id == 'new';

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    final list = await ref.read(allDiseasesProvider.future);
    final d = list.where((e) => e.id == widget.id).firstOrNull;
    if (d == null || !mounted) return;
    setState(() {
      _existing = d;
      _name.text = d.name;
      _short.text = d.shortDescription;
      _desc.text = d.description;
      _category.text = d.category ?? '';
      _icon.text = d.icon ?? '';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _desc.dispose();
    _category.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(diseaseRemoteProvider).save(
            Disease(
              id: _existing?.id ?? '',
              name: name,
              shortDescription: _short.text.trim(),
              description: _desc.text.trim(),
              category:
                  _category.text.trim().isEmpty ? null : _category.text.trim(),
              icon: _icon.text.trim().isEmpty ? null : _icon.text.trim(),
              status: _existing?.status ?? ContentStatus.draft,
            ),
            id: _existing?.id,
            uid: uid,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nueva enfermedad' : 'Editar enfermedad'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre *'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _short,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descripción corta'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Categoría'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _icon,
            decoration: const InputDecoration(
              labelText: 'Icono (nombre Material, opcional)',
              hintText: 'p.ej. favorite',
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_isNew ? 'Crear borrador' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
