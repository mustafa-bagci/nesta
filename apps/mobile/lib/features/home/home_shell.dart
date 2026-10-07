import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Alt menülü ana iskelet.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Ana Sayfa',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: 'Takip',
        ),
        NavigationDestination(
          icon: Icon(Icons.self_improvement_outlined),
          selectedIcon: Icon(Icons.self_improvement_rounded),
          label: 'Egzersiz',
        ),
        NavigationDestination(
          icon: Icon(Icons.lightbulb_outline_rounded),
          selectedIcon: Icon(Icons.lightbulb_rounded),
          label: 'İpuçları',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    ),
  );
}
