// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    LotusDestination(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    LotusDestination(
      label: 'Projetos',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    LotusDestination(
      label: 'Agentes',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
    ),
    LotusDestination(
      label: 'Terminal',
      icon: Icons.terminal_outlined,
      selectedIcon: Icons.terminal_rounded,
    ),
    LotusDestination(
      label: 'Ajustes',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  void _go(int index) {
    // Tapping the active destination returns to its initial route.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= LotusBreakpoints.expanded;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                LotusNavRail(
                  index: navigationShell.currentIndex,
                  destinations: destinations,
                  onSelected: _go,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: LotusBottomNav(
            index: navigationShell.currentIndex,
            destinations: destinations,
            onSelected: _go,
          ),
        );
      },
    );
  }
}
