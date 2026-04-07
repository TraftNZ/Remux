import 'package:flutter/material.dart';

class TerminalToolbar extends StatefulWidget {
  final void Function(String key) onKey;
  final VoidCallback onSnippets;
  final bool vertical;

  const TerminalToolbar({
    super.key,
    required this.onKey,
    required this.onSnippets,
    this.vertical = false,
  });

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  bool _ctrlActive = false;
  bool _altActive = false;

  @override
  Widget build(BuildContext context) {
    return widget.vertical ? _buildVertical(context) : _buildHorizontal(context);
  }

  Widget _buildHorizontal(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _buttons(vertical: false),
          ),
        ),
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    return Container(
      width: 56,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: _buttons(vertical: true),
        ),
      ),
    );
  }

  List<Widget> _buttons({required bool vertical}) {
    final divider = vertical
        ? const Divider(height: 1)
        : const VerticalDivider(width: 1);

    final tmuxLabel = vertical
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'C-b',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'C-b',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );

    return [
      _buildSnippetButton(vertical),
      divider,
      _buildToggleButton('Ctrl', _ctrlActive, () {
        setState(() => _ctrlActive = !_ctrlActive);
      }, vertical),
      _buildToggleButton('Alt', _altActive, () {
        setState(() => _altActive = !_altActive);
      }, vertical),
      _buildKeyButton('Esc', '\x1b', vertical),
      _buildKeyButton('Tab', '\t', vertical),
      _buildKeyButton('\u2191', '\x1b[A', vertical),
      _buildKeyButton('\u2193', '\x1b[B', vertical),
      _buildKeyButton('\u2190', '\x1b[D', vertical),
      _buildKeyButton('\u2192', '\x1b[C', vertical),
      divider,
      tmuxLabel,
      divider,
      _buildTmuxButton('c', 'c', vertical),
      for (final i in List.generate(10, (n) => n))
        _buildTmuxButton('$i', '$i', vertical),
      divider,
      _buildTmuxButton('[', '[', vertical),
      _buildTmuxButton(']', ']', vertical),
      divider,
      _buildKeyButton('PgUp', '\x1b[5~', vertical),
      _buildKeyButton('PgDn', '\x1b[6~', vertical),
      divider,
      _buildKeyButton('|', '|', vertical),
      _buildKeyButton('/', '/', vertical),
      _buildKeyButton('~', '~', vertical),
      _buildKeyButton('-', '-', vertical),
      _buildKeyButton('_', '_', vertical),
    ];
  }

  Widget _buildSnippetButton(bool vertical) {
    return IconButton(
      icon: const Icon(Icons.code, size: 20),
      tooltip: 'Snippets',
      onPressed: widget.onSnippets,
    );
  }

  Widget _buildToggleButton(
      String label, bool active, VoidCallback onPressed, bool vertical) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor:
              active ? Theme.of(context).colorScheme.primaryContainer : null,
          minimumSize: vertical ? const Size(48, 36) : const Size(44, 48),
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: vertical ? 11 : 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTmuxButton(String label, String key, bool vertical) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () => widget.onKey('\x02$key'),
        style: TextButton.styleFrom(
          minimumSize: vertical ? const Size(48, 34) : const Size(36, 40),
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildKeyButton(String label, String key, bool vertical) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () {
          String output = key;
          if (_ctrlActive && key.length == 1) {
            final code = key.toUpperCase().codeUnitAt(0);
            if (code >= 64 && code <= 95) {
              output = String.fromCharCode(code - 64);
            }
            setState(() => _ctrlActive = false);
          } else if (_altActive) {
            output = '\x1b$key';
            setState(() => _altActive = false);
          }
          widget.onKey(output);
        },
        style: TextButton.styleFrom(
          minimumSize: vertical ? const Size(48, 36) : const Size(44, 48),
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label,
            style: TextStyle(fontSize: vertical ? 12 : 13)),
      ),
    );
  }
}
