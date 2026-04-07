import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/snippet.dart';
import 'connections_provider.dart';

const _uuid = Uuid();

final snippetsProvider =
    AsyncNotifierProvider<SnippetsNotifier, List<Snippet>>(
  SnippetsNotifier.new,
);

class SnippetsNotifier extends AsyncNotifier<List<Snippet>> {
  @override
  Future<List<Snippet>> build() async {
    final storage = ref.read(storageServiceProvider);
    var snippets = await storage.loadSnippets();
    if (snippets.isEmpty) {
      snippets = [
        Snippet(
          id: _uuid.v4(),
          name: 'Claude Code',
          command: 'claude --dangerously-skip-permissions',
          group: 'AI',
        ),
        Snippet(
          id: _uuid.v4(),
          name: 'OpenCode',
          command: 'opencode',
          group: 'AI',
        ),
      ];
      await storage.saveSnippets(snippets);
    }
    return snippets;
  }

  Future<void> add(Snippet snippet) async {
    final storage = ref.read(storageServiceProvider);
    final current = await future;
    final updated = [...current, snippet.copyWith(id: _uuid.v4())];
    await storage.saveSnippets(updated);
    state = AsyncData(updated);
  }

  Future<void> updateSnippet(Snippet snippet) async {
    final storage = ref.read(storageServiceProvider);
    final current = await future;
    final updated = current.map((s) {
      return s.id == snippet.id ? snippet : s;
    }).toList();
    await storage.saveSnippets(updated);
    state = AsyncData(updated);
  }

  Future<void> delete(String id) async {
    final storage = ref.read(storageServiceProvider);
    final current = await future;
    final updated = current.where((s) => s.id != id).toList();
    await storage.saveSnippets(updated);
    state = AsyncData(updated);
  }
}
