import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'El email no es válido.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email o contraseña incorrectos.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con ese email.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        case 'network-request-failed':
          return 'Sin conexión a Internet.';
        case 'too-many-requests':
          return 'Demasiados intentos. Inténtalo más tarde.';
      }
    }
    return 'No se pudo completar la operación.';
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Escribe tu email y tu contraseña.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_register) {
        final n = _name.text.trim();
        await repo.register(_email.text.trim(), _pass.text,
            displayName: n.isEmpty ? null : n);
      } else {
        await repo.signIn(_email.text.trim(), _pass.text);
      }
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu email para recuperar la contraseña.');
      return;
    }
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Te hemos enviado un email para restablecerla.')));
    } catch (e) {
      setState(() => _error = _friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        // ── Cabecera de marca ──
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(36)),
          ),
          child: Stack(children: [
            Positioned(
                right: -40,
                top: -40,
                child: _Blob(size: 180, color: c.primary.withAlpha(40))),
            Positioned(
                left: -30,
                bottom: -50,
                child: _Blob(size: 140, color: c.primary.withAlpha(30))),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 56, 24, 44),
              child: Column(children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: c.primary.withAlpha(90),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Icon(Icons.monitor_heart_rounded,
                      size: 46, color: c.onPrimary),
                ),
                const SizedBox(height: 18),
                Text('Kinea',
                    style: t.headlineLarge?.copyWith(
                        color: c.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Muévete a tu ritmo, cuida tu salud',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: c.onPrimaryContainer)),
              ]),
            ),
          ]),
        ),

        // ── Formulario ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_register ? 'Crea tu cuenta' : 'Bienvenido de nuevo',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                _register
                    ? 'Empieza a entrenar en un minuto'
                    : 'Inicia sesión para continuar',
                style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (_register) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _reset,
                    child: const Text('¿Olvidaste tu contraseña?')),
              ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, size: 18, color: c.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!, style: TextStyle(color: c.error))),
                ]),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: c.onPrimary))
                  : Text(_register ? 'Crear cuenta' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_register ? '¿Ya tienes cuenta?' : '¿Aún no tienes cuenta?',
                  style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
              TextButton(
                onPressed: () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
                child: Text(_register ? 'Inicia sesión' : 'Regístrate',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
