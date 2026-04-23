import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';
import '../providers/snippets_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/connection_tile.dart';
import '../widgets/identity_tile.dart';
import '../widgets/snippet_tile.dart';
import '../widgets/quick_connect.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;

  static const _breakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionProvider).sessions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpoint;

        final destinations = [
          const NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns),
            label: 'Connections',
          ),
          const NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: 'Snippets',
          ),
          const NavigationDestination(
            icon: Icon(Icons.key_outlined),
            selectedIcon: Icon(Icons.key),
            label: 'Identities',
          ),
        ];

        final body = IndexedStack(
          index: _currentTab,
          children: [
            _ConnectionsTab(isWide: isWide),
            _SnippetsTab(),
            _IdentitiesTab(),
          ],
        );

        if (isWide) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Remux'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: _addTooltip,
                  onPressed: _onAddPressed,
                ),
              ],
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentTab,
                  onDestinationSelected: (i) =>
                      setState(() => _currentTab = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map((d) => NavigationRailDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon ?? d.icon,
                            label: Text(d.label),
                          ))
                      .toList(),
                  // Action buttons at the bottom of the rail (right-side feel)
                  trailing: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sessions.isNotEmpty)
                          IconButton(
                            icon: Badge(
                              label: Text('${sessions.length}'),
                              child: const Icon(Icons.terminal),
                            ),
                            tooltip: 'Active sessions',
                            onPressed: () => context.push('/terminal'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Settings',
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Narrow layout: standard bottom nav
        return Scaffold(
          appBar: AppBar(
            title: const Text('Remux'),
            actions: [
              if (sessions.isNotEmpty)
                IconButton(
                  icon: Badge(
                    label: Text('${sessions.length}'),
                    child: const Icon(Icons.terminal),
                  ),
                  onPressed: () => context.push('/terminal'),
                ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: _addTooltip,
                onPressed: _onAddPressed,
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (i) => setState(() => _currentTab = i),
            destinations: destinations,
          ),
        );
      },
    );
  }

  String get _addTooltip {
    switch (_currentTab) {
      case 1:
        return 'Add snippet';
      case 2:
        return 'Add identity';
      default:
        return 'Add connection';
    }
  }

  void _onAddPressed() {
    switch (_currentTab) {
      case 1:
        context.push('/snippet/add');
      case 2:
        context.push('/identity/add');
      default:
        context.push('/connection/add');
    }
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _ConnectionsTab extends ConsumerWidget {
  final bool isWide;

  const _ConnectionsTab({required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsProvider);
    return connections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        return ListView(
          children: [
            const QuickConnect(),
            const Divider(),
            if (!Platform.isIOS)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.computer, size: 18),
                ),
                title: const Text('Local Shell'),
                subtitle: const Text('Open a terminal on this device'),
                onTap: () {
                  ref.read(sessionProvider.notifier).connectLocal();
                  context.push('/terminal');
                },
              ),
            if (list.isEmpty) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dns_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No connections yet'),
                    SizedBox(height: 8),
                    Text('Tap + to add one, or use Quick Connect above'),
                  ],
                ),
              ),
            ] else ...[
              const Divider(),
              ...list.map((c) => ConnectionTile(connection: c)),
            ],
          ],
        );
      },
    );
  }
}

class _SnippetsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snippets = ref.watch(snippetsProvider);
    return snippets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No snippets yet'),
                SizedBox(height: 8),
                Text('Tap + to add custom commands'),
              ],
            ),
          );
        }

        final grouped = <String, List<dynamic>>{};
        for (final s in list) {
          final group = s.group ?? 'General';
          grouped.putIfAbsent(group, () => []).add(s);
        }

        return ListView(
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              ...entry.value.map((s) => SnippetTile(snippet: s)),
            ],
          ],
        );
      },
    );
  }
}

class _IdentitiesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identities = ref.watch(identitiesProvider);
    return identities.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.key_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No identities yet'),
                SizedBox(height: 8),
                Text('Tap + to add SSH credentials'),
              ],
            ),
          );
        }
        return ListView(
          children: list.map((i) => IdentityTile(identity: i)).toList(),
        );
      },
    );
  }
}
