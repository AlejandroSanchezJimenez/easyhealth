import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell del panel de maestro — 3 secciones: Enfermedades, Ejercicios, Clases.
class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (path: '/teacher/diseases', icon: Icons.healing_outlined, label: 'Enfermedades'),
    (path: '/teacher/exercises', icon: Icons.fitness_center_outlined, label: 'Ejercicios'),
    (path: '/teacher/workouts', icon: Icons.class_outlined, label: 'Clases'),
  ];

  int _index(String loc) {
    for (var i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _index(loc);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de maestro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
