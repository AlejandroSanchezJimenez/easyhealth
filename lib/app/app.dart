import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/daily_reminders_provider.dart';
import '../features/auth/auth_providers.dart';
import '../features/streak/streak_providers.dart';
import 'routes.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncServiceProvider); // arranca la sincronización al abrir la app
    ref.watch(dailyRemindersProvider); // avisos del día según si ya entrenó
    ref.watch(publishMyProfileProvider); // publica mi foto para mis amigos

    // Cuando la sesión se cierra DE VERDAD, el loader ya no hace falta: en ese
    // momento la pantalla de login ya está debajo. Quitarlo antes daría el
    // parpadeo de "pantalla normal" que había.
    ref.listen(currentUserProvider, (_, next) {
      if (next == null) {
        ref.read(deletingAccountProvider.notifier).state = false;
      }
    });

    final deleting = ref.watch(deletingAccountProvider);
    final signedIn = ref.watch(currentUserProvider) != null;

    return MaterialApp.router(
      title: 'Kineo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          // Se mantiene mientras se borra Y sigo con sesión: así tapa la
          // pantalla normal hasta que el router cambia al login.
          if (deleting && signedIn) const _DeletingAccountOverlay(),
        ],
      ),
    );
  }
}

/// Capa opaca que tapa toda la app mientras se borra la cuenta.
class _DeletingAccountOverlay extends StatelessWidget {
  const _DeletingAccountOverlay();

  @override
  Widget build(BuildContext context) {
    // AbsorbPointer corta los toques: sin él, se podría pulsar lo de debajo.
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Borrando tu cuenta…',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Esto puede tardar unos segundos.',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
