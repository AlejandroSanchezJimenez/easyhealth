import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_banner.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        // Banner encima de la barra de navegación.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AdBanner(),
            NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
                NavigationDestination(
                    icon: Icon(Icons.local_fire_department_outlined),
                    label: 'Progreso'),
                NavigationDestination(
                    icon: Icon(Icons.group_outlined), label: 'Amigos'),
                NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
              ],
            ),
          ],
        ),
      );
}
