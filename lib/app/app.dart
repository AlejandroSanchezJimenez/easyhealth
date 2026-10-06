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
    return MaterialApp.router(
      title: 'Kinea',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
