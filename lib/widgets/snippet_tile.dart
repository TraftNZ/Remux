import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/snippet.dart';
import '../providers/snippets_provider.dart';
import '../providers/session_provider.dart';

class SnippetTile extends ConsumerWidget {
  final Snippet snippet;

  const SnippetTile({super.key, required this.snippet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveSession = ref.watch(sessionProvider).sessions.isNotEmpty;

    return Dismissible(
      key: Key(snippet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Snippet'),
            content: Text('Delete "${snippet.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(snippetsProvider.notifier).delete(snippet.id);
      },
      child: ListTile(
        leading: const Icon(Icons.code),
        title: Text(snippet.name),
        subtitle: Text(
          snippet.command,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasActiveSession)
              IconButton(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Run in active session',
                onPressed: () {
                  ref.read(sessionProvider.notifier).sendSnippet(snippet.command);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sent: ${snippet.name}')),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/snippet/edit/${snippet.id}'),
            ),
          ],
        ),
      ),
    );
  }
}
