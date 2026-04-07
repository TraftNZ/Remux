import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/connection.dart';
import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';
import '../providers/session_provider.dart';

class ConnectionTile extends ConsumerStatefulWidget {
  final Connection connection;

  const ConnectionTile({super.key, required this.connection});

  @override
  ConsumerState<ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState extends ConsumerState<ConnectionTile> {
  bool _connecting = false;

  IconData get _typeIcon => switch (widget.connection.type) {
        ConnectionType.mosh => Icons.bolt,
        ConnectionType.ssh => Icons.terminal,
      };

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.connection.id),
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
            title: const Text('Delete Connection'),
            content: Text('Delete "${widget.connection.name}"?'),
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
        ref.read(connectionsProvider.notifier).delete(widget.connection.id);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Icon(_typeIcon, size: 18),
            ),
            title: Text(widget.connection.name),
            subtitle: Text(
              widget.connection.type == ConnectionType.mosh
                  ? widget.connection.host
                  : '${widget.connection.host}:${widget.connection.port}'
                      '${widget.connection.tmuxSession != null ? ' (tmux: ${widget.connection.tmuxSession})' : ''}',
            ),
            trailing: _connecting
                ? null
                : IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context
                        .push('/connection/edit/${widget.connection.id}'),
                  ),
            enabled: !_connecting,
            onTap: _connecting ? null : _connect,
            onLongPress: _connecting ? null : _copyHost,
          ),
          if (_connecting) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  void _copyHost() {
    Clipboard.setData(ClipboardData(text: widget.connection.host));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: ${widget.connection.host}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _connect() async {
    switch (widget.connection.type) {
      case ConnectionType.ssh:
        await _connectSsh();
      case ConnectionType.mosh:
        await _connectMosh();
    }
  }

  Future<void> _connectSsh() async {
    final identities = ref.read(identitiesProvider).valueOrNull ?? [];
    final identity = identities
        .where((i) => i.id == widget.connection.identityId)
        .firstOrNull;

    if (identity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No identity assigned to this connection')),
      );
      return;
    }

    setState(() => _connecting = true);
    try {
      await ref.read(sessionProvider.notifier).connect(
            connection: widget.connection,
            identity: identity,
          );
      if (mounted) context.push('/terminal');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _connectMosh() async {
    final identities = ref.read(identitiesProvider).valueOrNull ?? [];
    final identity = identities
        .where((i) => i.id == widget.connection.identityId)
        .firstOrNull;

    if (identity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No identity assigned to this connection')),
      );
      return;
    }

    setState(() => _connecting = true);
    try {
      await ref.read(sessionProvider.notifier).connectMosh(
            connection: widget.connection,
            identity: identity,
          );
      if (mounted) context.push('/terminal');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mosh connection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }
}
