import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/agents/presentation/agents_page.dart';
import '../features/chat/presentation/chat_shell_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/terminal/presentation/terminal_page.dart';
import 'shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/chat', builder: (_, __) => const ChatShellPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (_, __) => const ProjectsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/agents', builder: (_, __) => const AgentsPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/terminal',
                builder: (_, __) => const TerminalPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
