import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/connection.dart';
import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';

class ConnectionEditScreen extends ConsumerStatefulWidget {
  final String? connectionId;

  const ConnectionEditScreen({super.key, this.connectionId});

  @override
  ConsumerState<ConnectionEditScreen> createState() =>
      _ConnectionEditScreenState();
}

class _ConnectionEditScreenState extends ConsumerState<ConnectionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _tmuxCtrl = TextEditingController();
  final _startupCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  String? _selectedIdentityId;
  ConnectionType _type = ConnectionType.ssh;

  // Mosh supported on all platforms (desktop: binary, mobile: mosh_dart)
  bool get _showMoshOption => true;

  bool get _isEditing => widget.connectionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final connections = ref.read(connectionsProvider).valueOrNull ?? [];
        final conn =
            connections.where((c) => c.id == widget.connectionId).firstOrNull;
        if (conn != null) {
          _nameCtrl.text = conn.name;
          _hostCtrl.text = conn.host;
          _portCtrl.text = conn.port.toString();
          _tmuxCtrl.text = conn.tmuxSession ?? '';
          _startupCtrl.text = conn.startupCommand ?? '';
          _groupCtrl.text = conn.group ?? '';
          setState(() {
            _selectedIdentityId = conn.identityId;
            _type = conn.type;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _tmuxCtrl.dispose();
    _startupCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identities = ref.watch(identitiesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Connection' : 'New Connection'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection type selector (desktop only)
            if (_showMoshOption) ...[
              SegmentedButton<ConnectionType>(
                segments: const [
                  ButtonSegment(
                    value: ConnectionType.ssh,
                    label: Text('SSH'),
                    icon: Icon(Icons.lock_outline),
                  ),
                  ButtonSegment(
                    value: ConnectionType.mosh,
                    label: Text('Mosh'),
                    icon: Icon(Icons.bolt),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (v) =>
                    setState(() => _type = v.first),
              ),
              if (_type == ConnectionType.mosh)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Requires mosh and mosh-server in PATH on both machines.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'My Server',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostCtrl,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '192.168.1.100 or example.com',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Host is required' : null,
            ),
            const SizedBox(height: 16),
            // Mosh auto-detects port — hide for mosh connections
            if (_type == ConnectionType.ssh) ...[
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Port is required';
                  final port = int.tryParse(v);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Invalid port (1-65535)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: _selectedIdentityId,
              decoration: const InputDecoration(
                labelText: 'Identity',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('None'),
                ),
                ...identities.map((i) => DropdownMenuItem(
                      value: i.id,
                      child: Text('${i.name} (${i.username})'),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedIdentityId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tmuxCtrl,
              decoration: const InputDecoration(
                labelText: 'Tmux Session (optional)',
                hintText: 'main',
                helperText: 'Auto-attach to this tmux session on connect',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _startupCtrl,
              decoration: const InputDecoration(
                labelText: 'Startup Command (optional)',
                hintText: 'cd ~/project && ls',
                helperText:
                    'Run after connecting (ignored if tmux session set)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupCtrl,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                hintText: 'Work',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final connection = Connection(
      id: widget.connectionId ?? '',
      name: _nameCtrl.text,
      host: _hostCtrl.text,
      port: _type == ConnectionType.mosh ? 22 : int.parse(_portCtrl.text),
      type: _type,
      identityId: _selectedIdentityId,
      tmuxSession: _tmuxCtrl.text.isEmpty ? null : _tmuxCtrl.text,
      startupCommand: _startupCtrl.text.isEmpty ? null : _startupCtrl.text,
      group: _groupCtrl.text.isEmpty ? null : _groupCtrl.text,
    );

    if (_isEditing) {
      await ref.read(connectionsProvider.notifier).updateConnection(connection);
    } else {
      await ref.read(connectionsProvider.notifier).add(connection);
    }

    if (mounted) context.pop();
  }
}
