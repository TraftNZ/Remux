import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/connection.dart';
import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';
import '../providers/session_provider.dart';

enum _ConnectionAction { edit, duplicate }

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
            subtitle: Text(_subtitle()),
            trailing: _connecting
                ? null
                : PopupMenuButton<_ConnectionAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _ConnectionAction.edit:
                          context.push('/connection/edit/${widget.connection.id}');
                        case _ConnectionAction.duplicate:
                          _duplicateConnection();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ConnectionAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _ConnectionAction.duplicate,
                        child: ListTile(
                          leading: Icon(Icons.copy),
                          title: Text('Duplicate'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
            enabled: !_connecting,
            onTap: _connecting ? null : _connect,
          ),
          if (_connecting) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  String _subtitle() {
    final conn = widget.connection;
    if (conn.type == ConnectionType.mosh) return conn.host;

    final buffer = StringBuffer('${conn.host}:${conn.port}');
    if (conn.jumpHostId != null) {
      final connections = ref.watch(connectionsProvider).valueOrNull ?? [];
      final bridge =
          connections.where((c) => c.id == conn.jumpHostId).firstOrNull;
      buffer.write(' via ${bridge?.name ?? 'missing jump host'}');
    }
    if (conn.portForwards.isNotEmpty) {
      final count = conn.portForwards.length;
      buffer.write(count == 1 ? ' · 1 forward' : ' · $count forwards');
    }
    if (conn.tmuxSession != null) {
      buffer.write(' (tmux: ${conn.tmuxSession})');
    }
    return buffer.toString();
  }

  Future<void> _duplicateConnection() async {
    final duplicate = widget.connection.copyWith(
      id: '',
      name: '${widget.connection.name} (copy)',
    );
    await ref.read(connectionsProvider.notifier).add(duplicate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated: ${widget.connection.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
