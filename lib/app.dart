import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/app_settings.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/connection_edit_screen.dart';
import 'screens/identity_edit_screen.dart';
import 'screens/snippet_edit_screen.dart';
import 'screens/settings_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/terminal',
      builder: (context, state) => const TerminalScreen(),
    ),
    GoRoute(
      path: '/connection/add',
      builder: (context, state) => const ConnectionEditScreen(),
    ),
    GoRoute(
      path: '/connection/edit/:id',
      builder: (context, state) => ConnectionEditScreen(
        connectionId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/identity/add',
      builder: (context, state) => const IdentityEditScreen(),
    ),
    GoRoute(
      path: '/identity/edit/:id',
      builder: (context, state) => IdentityEditScreen(
        identityId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/snippet/add',
      builder: (context, state) => const SnippetEditScreen(),
    ),
    GoRoute(
      path: '/snippet/edit/:id',
      builder: (context, state) => SnippetEditScreen(
        snippetId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class RemuxApp extends ConsumerWidget {
  const RemuxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final seed = settings.accentColor.color;

    return MaterialApp.router(
      title: 'Remux',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: switch (settings.appThemeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: _router,
    );
  }
}
