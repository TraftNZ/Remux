import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';
import '../providers/session_provider.dart';

class QuickConnect extends ConsumerStatefulWidget {
  const QuickConnect({super.key});

  @override
  ConsumerState<QuickConnect> createState() => _QuickConnectState();
}

class _QuickConnectState extends ConsumerState<QuickConnect> {
  final _hostCtrl = TextEditingController();
  String? _selectedIdentityId;
  bool _connecting = false;

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identities = ref.watch(identitiesProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                hintText: 'user@host:port',
                prefixIcon: Icon(Icons.flash_on),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _quickConnect(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedIdentityId,
              decoration: const InputDecoration(
                hintText: 'Identity',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              isExpanded: true,
              items: identities.isEmpty
                  ? [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'No identities — add one first',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ]
                  : identities
                      .map((i) => DropdownMenuItem(
                            value: i.id,
                            child:
                                Text(i.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
              onChanged: identities.isEmpty
                  ? null
                  : (v) => setState(() => _selectedIdentityId = v),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _connecting ? null : _quickConnect,
            icon: _connecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  Future<void> _quickConnect() async {
    final input = _hostCtrl.text.trim();
    if (input.isEmpty) return;

    // Parse user@host:port format
    String host;
    int port = 22;
    String? username;

    String hostPart = input;
    if (input.contains('@')) {
      final parts = input.split('@');
      username = parts[0];
      hostPart = parts[1];
    }
    if (hostPart.contains(':')) {
      final parts = hostPart.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 22;
    } else {
      host = hostPart;
    }

    // Find or create identity
    final identities = ref.read(identitiesProvider).valueOrNull ?? [];
    Identity? identity;

    if (_selectedIdentityId != null) {
      identity = identities
          .where((i) => i.id == _selectedIdentityId)
          .firstOrNull;
    }

    if (identity == null && username != null) {
      // Try to find identity by username
      identity = identities
          .where((i) => i.username == username)
          .firstOrNull;
    }

    if (identity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an identity')),
      );
      return;
    }

    setState(() => _connecting = true);

    try {
      final connection = Connection(
        id: '',
        name: host,
        host: host,
        port: port,
      );

      await ref.read(sessionProvider.notifier).connect(
            connection: connection,
            identity: identity,
          );

      // Save quick connect as a new connection
      await ref.read(connectionsProvider.notifier).add(
            connection.copyWith(
              name: input,
              identityId: identity.id,
            ),
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
}
