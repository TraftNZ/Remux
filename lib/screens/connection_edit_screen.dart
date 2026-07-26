import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/connection.dart';
import '../models/port_forward.dart';
import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';

const _uuid = Uuid();
const _maxPort = 65535;

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
  String? _selectedJumpHostId;
  List<PortForward> _portForwards = [];
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
            _selectedJumpHostId = conn.jumpHostId;
            _portForwards = [...conn.portForwards];
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
                  if (port == null || port < 1 || port > _maxPort) {
                    return 'Invalid port (1-$_maxPort)';
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
            // Mosh runs over UDP and cannot be tunnelled through an SSH
            // bridge, so the jump host only applies to SSH connections.
            if (_type == ConnectionType.ssh) ...[
              DropdownButtonFormField<String>(
                initialValue: _jumpHostCandidates().any(
                        (c) => c.id == _selectedJumpHostId)
                    ? _selectedJumpHostId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Jump Host (optional)',
                  helperText: 'Connect through this bridge machine',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None (direct)'),
                  ),
                  ..._jumpHostCandidates().map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.host}:${c.port})'),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedJumpHostId = v),
              ),
              const SizedBox(height: 16),
              // Tunnels ride the SSH transport, so mosh connections can't
              // carry them.
              _buildPortForwards(context),
              const SizedBox(height: 16),
            ],
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

  Widget _buildPortForwards(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Port Forwards (optional)',
        helperText: 'Tunnels opened automatically on connect',
        border: OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final forward in _portForwards)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                forward.type == PortForwardType.local
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 18,
              ),
              title: Text(
                forward.description,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
                onPressed: () => setState(
                  () => _portForwards.removeWhere((f) => f.id == forward.id),
                ),
              ),
              onTap: () => _editPortForward(forward),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _editPortForward(null),
              icon: const Icon(Icons.add),
              label: const Text('Add port forward'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPortForward(PortForward? existing) async {
    final result = await showDialog<PortForward>(
      context: context,
      builder: (_) => _PortForwardDialog(forward: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _portForwards.indexWhere((f) => f.id == result.id);
      if (index == -1) {
        _portForwards.add(result);
      } else {
        _portForwards[index] = result;
      }
    });
  }

  /// SSH connections usable as a bridge for the connection being edited:
  /// everything except itself and anything whose own jump-host chain leads
  /// back here (which would deadlock the dial chain).
  List<Connection> _jumpHostCandidates() {
    final connections = ref.read(connectionsProvider).valueOrNull ?? [];
    final self = widget.connectionId;
    return connections.where((c) {
      if (c.type != ConnectionType.ssh) return false;
      if (self == null) return true;
      if (c.id == self) return false;
      final visited = <String>{c.id};
      var next = c.jumpHostId;
      while (next != null) {
        if (next == self) return false;
        if (!visited.add(next)) return false;
        next = connections.where((x) => x.id == next).firstOrNull?.jumpHostId;
      }
      return true;
    }).toList();
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
      jumpHostId: _type == ConnectionType.ssh ? _selectedJumpHostId : null,
      portForwards: _type == ConnectionType.ssh ? _portForwards : const [],
    );

    if (_isEditing) {
      await ref.read(connectionsProvider.notifier).updateConnection(connection);
    } else {
      await ref.read(connectionsProvider.notifier).add(connection);
    }

    if (mounted) context.pop();
  }
}

/// Add/edit form for a single [PortForward]. Pops the edited value, or null
/// when cancelled.
class _PortForwardDialog extends StatefulWidget {
  final PortForward? forward;

  const _PortForwardDialog({this.forward});

  @override
  State<_PortForwardDialog> createState() => _PortForwardDialogState();
}

class _PortForwardDialogState extends State<_PortForwardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _listenPortCtrl;
  late final TextEditingController _targetHostCtrl;
  late final TextEditingController _targetPortCtrl;
  late PortForwardType _type;

  @override
  void initState() {
    super.initState();
    final forward = widget.forward;
    _type = forward?.type ?? PortForwardType.local;
    _listenPortCtrl =
        TextEditingController(text: forward?.listenPort.toString() ?? '');
    _targetHostCtrl =
        TextEditingController(text: forward?.targetHost ?? 'localhost');
    _targetPortCtrl =
        TextEditingController(text: forward?.targetPort.toString() ?? '');
  }

  @override
  void dispose() {
    _listenPortCtrl.dispose();
    _targetHostCtrl.dispose();
    _targetPortCtrl.dispose();
    super.dispose();
  }

  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final port = int.tryParse(value);
    if (port == null || port < 1 || port > _maxPort) {
      return 'Invalid port (1-$_maxPort)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = _type == PortForwardType.local;
    return AlertDialog(
      title: Text(widget.forward == null ? 'Add Port Forward' : 'Port Forward'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<PortForwardType>(
              segments: const [
                ButtonSegment(
                  value: PortForwardType.local,
                  label: Text('Local'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: PortForwardType.remote,
                  label: Text('Remote'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 8),
            Text(
              isLocal
                  ? 'This device listens; traffic comes out on the server '
                      '(ssh -L).'
                  : 'The server listens; traffic comes out on this device '
                      '(ssh -R).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _listenPortCtrl,
              decoration: InputDecoration(
                labelText: isLocal ? 'Local port' : 'Server port',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: _validatePort,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetHostCtrl,
              decoration: InputDecoration(
                labelText: 'Target host',
                helperText: isLocal
                    ? 'Resolved on the server'
                    : 'Resolved on this device',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Target host is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetPortCtrl,
              decoration: const InputDecoration(
                labelText: 'Target port',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: _validatePort,
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              PortForward(
                id: widget.forward?.id ?? _uuid.v4(),
                type: _type,
                listenPort: int.parse(_listenPortCtrl.text),
                targetHost: _targetHostCtrl.text,
                targetPort: int.parse(_targetPortCtrl.text),
              ),
            );
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
