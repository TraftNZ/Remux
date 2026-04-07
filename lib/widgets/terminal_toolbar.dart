import 'package:flutter/material.dart';

class TerminalToolbar extends StatelessWidget {
  final void Function(String key) onKey;
  final VoidCallback onSnippets;
  final bool vertical;
  final VoidCallback? onSidebar;
  final bool ctrlActive;
  final bool altActive;
  final VoidCallback onCtrlToggle;
  final VoidCallback onAltToggle;

  const TerminalToolbar({
    super.key,
    required this.onKey,
    required this.onSnippets,
    this.vertical = false,
    this.onSidebar,
    required this.ctrlActive,
    required this.altActive,
    required this.onCtrlToggle,
    required this.onAltToggle,
  });

  @override
  Widget build(BuildContext context) {
    return vertical ? _buildVertical(context) : _buildHorizontal(context);
  }

  Widget _buildHorizontal(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _buttons(context, vertical: false),
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
          children: _buttons(context, vertical: true),
        ),
      ),
    );
  }

  List<Widget> _buttons(BuildContext context, {required bool vertical}) {
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
      if (onSidebar != null) ...[
        _buildSidebarButton(),
        divider,
      ],
      _buildSnippetButton(),
      divider,
      _buildToggleButton(context, 'Ctrl', ctrlActive, onCtrlToggle, vertical),
      _buildToggleButton(context, 'Alt', altActive, onAltToggle, vertical),
      _buildKeyButton(context, 'Esc', '\x1b', vertical),
      _buildKeyButton(context, 'Tab', '\t', vertical),
      _buildKeyButton(context, '\u2191', '\x1b[A', vertical),
      _buildKeyButton(context, '\u2193', '\x1b[B', vertical),
      _buildKeyButton(context, '\u2190', '\x1b[D', vertical),
      _buildKeyButton(context, '\u2192', '\x1b[C', vertical),
      _buildKeyButton(context, 'C-c', '\x03', vertical),
      divider,
      tmuxLabel,
      divider,
      _buildTmuxButton('c', 'c', vertical),
      _buildTmuxButton('d', 'd', vertical),
      for (final i in List.generate(10, (n) => n))
        _buildTmuxButton('$i', '$i', vertical),
      divider,
      _buildTmuxButton('[', '[', vertical),
      _buildTmuxButton(']', ']', vertical),
      divider,
      _buildKeyButton(context, 'PgUp', '\x1b[5~', vertical),
      _buildKeyButton(context, 'PgDn', '\x1b[6~', vertical),
      divider,
      _buildKeyButton(context, '|', '|', vertical),
      _buildKeyButton(context, '/', '/', vertical),
      _buildKeyButton(context, '~', '~', vertical),
      _buildKeyButton(context, '-', '-', vertical),
      _buildKeyButton(context, '_', '_', vertical),
    ];
  }

  Widget _buildSidebarButton() {
    return IconButton(
      icon: const Icon(Icons.menu, size: 20),
      tooltip: 'Show sidebar',
      onPressed: onSidebar,
    );
  }

  Widget _buildSnippetButton() {
    return IconButton(
      icon: const Icon(Icons.code, size: 20),
      tooltip: 'Snippets',
      onPressed: onSnippets,
    );
  }

  Widget _buildToggleButton(BuildContext context, String label, bool active,
      VoidCallback onToggle, bool vertical) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onToggle,
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
        onPressed: () => onKey('\x02$key'),
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

  String _applyCtrl(String key) {
    if (key.length == 1) {
      return String.fromCharCode(key.codeUnitAt(0) & 0x1f);
    }
    final arrowMatch = RegExp(r'^\x1b\[([ABCD])$').firstMatch(key);
    if (arrowMatch != null) return '\x1b[1;5${arrowMatch.group(1)}';
    final tildeMatch = RegExp(r'^\x1b\[(\d+)~$').firstMatch(key);
    if (tildeMatch != null) return '\x1b[${tildeMatch.group(1)};5~';
    return key;
  }

  String _applyAlt(String key) {
    if (key.length == 1) return '\x1b$key';
    final arrowMatch = RegExp(r'^\x1b\[([ABCD])$').firstMatch(key);
    if (arrowMatch != null) return '\x1b[1;3${arrowMatch.group(1)}';
    final tildeMatch = RegExp(r'^\x1b\[(\d+)~$').firstMatch(key);
    if (tildeMatch != null) return '\x1b[${tildeMatch.group(1)};3~';
    return '\x1b$key';
  }

  Widget _buildKeyButton(
      BuildContext context, String label, String key, bool vertical) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () {
          if (ctrlActive) {
            onKey(_applyCtrl(key));
            onCtrlToggle(); // deactivate after use
          } else if (altActive) {
            onKey(_applyAlt(key));
            onAltToggle(); // deactivate after use
          } else {
            onKey(key);
          }
        },
        style: TextButton.styleFrom(
          minimumSize: vertical ? const Size(48, 36) : const Size(44, 48),
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 8),
        ),
        child:
            Text(label, style: TextStyle(fontSize: vertical ? 12 : 13)),
      ),
    );
  }
}
