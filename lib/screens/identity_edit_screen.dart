import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/identity.dart';
import '../providers/identities_provider.dart';
class IdentityEditScreen extends ConsumerStatefulWidget {
  final String? identityId;

  const IdentityEditScreen({super.key, this.identityId});

  @override
  ConsumerState<IdentityEditScreen> createState() =>
      _IdentityEditScreenState();
}

class _IdentityEditScreenState extends ConsumerState<IdentityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _passphraseCtrl = TextEditingController();
  AuthType _authType = AuthType.password;

  bool get _isEditing => widget.identityId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final identities = ref.read(identitiesProvider).valueOrNull ?? [];
        final ident =
            identities.where((i) => i.id == widget.identityId).firstOrNull;
        if (ident != null) {
          _nameCtrl.text = ident.name;
          _usernameCtrl.text = ident.username;
          _passwordCtrl.text = ident.password ?? '';
          _keyCtrl.text = ident.privateKey ?? '';
          _passphraseCtrl.text = ident.passphrase ?? '';
          setState(() => _authType = ident.authType);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _keyCtrl.dispose();
    _passphraseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Identity' : 'New Identity'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Work Server Key',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'root',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Username is required' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<AuthType>(
              segments: const [
                ButtonSegment(
                  value: AuthType.password,
                  label: Text('Password'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: AuthType.key,
                  label: Text('SSH Key'),
                  icon: Icon(Icons.vpn_key),
                ),
              ],
              selected: {_authType},
              onSelectionChanged: (v) {
                setState(() => _authType = v.first);
              },
            ),
            const SizedBox(height: 16),
            if (_authType == AuthType.password) ...[
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _keyCtrl,
                decoration: InputDecoration(
                  labelText: 'Private Key (PEM)',
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _keyCtrl.text = data!.text!;
                      }
                    },
                    tooltip: 'Paste key',
                  ),
                ),
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Private key is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passphraseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Passphrase (optional)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
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

    final identity = Identity(
      id: widget.identityId ?? '',
      name: _nameCtrl.text,
      username: _usernameCtrl.text,
      authType: _authType,
      password: _authType == AuthType.password ? _passwordCtrl.text : null,
      privateKey: _authType == AuthType.key ? _keyCtrl.text : null,
      passphrase: _authType == AuthType.key && _passphraseCtrl.text.isNotEmpty
          ? _passphraseCtrl.text
          : null,
    );

    if (_isEditing) {
      await ref.read(identitiesProvider.notifier).updateIdentity(identity);
    } else {
      await ref.read(identitiesProvider.notifier).add(identity);
    }

    if (mounted) context.pop();
  }
}
