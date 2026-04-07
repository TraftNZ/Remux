import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/snippet.dart';
import '../providers/snippets_provider.dart';

class SnippetEditScreen extends ConsumerStatefulWidget {
  final String? snippetId;

  const SnippetEditScreen({super.key, this.snippetId});

  @override
  ConsumerState<SnippetEditScreen> createState() => _SnippetEditScreenState();
}

class _SnippetEditScreenState extends ConsumerState<SnippetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _commandCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  bool get _isEditing => widget.snippetId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final snippets = ref.read(snippetsProvider).valueOrNull ?? [];
        final snippet =
            snippets.where((s) => s.id == widget.snippetId).firstOrNull;
        if (snippet != null) {
          _nameCtrl.text = snippet.name;
          _commandCtrl.text = snippet.command;
          _groupCtrl.text = snippet.group ?? '';
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commandCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Snippet' : 'New Snippet'),
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
                hintText: 'Restart Service',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commandCtrl,
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'sudo systemctl restart nginx',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Command is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupCtrl,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                hintText: 'DevOps',
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

    final snippet = Snippet(
      id: widget.snippetId ?? '',
      name: _nameCtrl.text,
      command: _commandCtrl.text,
      group: _groupCtrl.text.isEmpty ? null : _groupCtrl.text,
    );

    if (_isEditing) {
      await ref.read(snippetsProvider.notifier).updateSnippet(snippet);
    } else {
      await ref.read(snippetsProvider.notifier).add(snippet);
    }

    if (mounted) context.pop();
  }
}
