import 'package:flutter/material.dart';

enum _ToolbarGroup { primary, keys, tmux, fn }

class TerminalToolbar extends StatefulWidget {
  final void Function(String key) onKey;
  final VoidCallback onSnippets;
  final bool vertical;
  final VoidCallback? onSidebar;
  final bool ctrlActive;
  final bool altActive;
  final VoidCallback onCtrlToggle;
  final VoidCallback onAltToggle;
  final VoidCallback? onKeyboardToggle;
  final bool softKeyboardVisible;

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
    this.onKeyboardToggle,
    this.softKeyboardVisible = true,
  });

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  _ToolbarGroup _group = _ToolbarGroup.primary;

  void _setGroup(_ToolbarGroup g) => setState(() => _group = g);

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
    switch (_group) {
      case _ToolbarGroup.primary:
        return _primaryButtons(context, vertical);
      case _ToolbarGroup.keys:
        return _keysButtons(context, vertical);
      case _ToolbarGroup.tmux:
        return _tmuxButtons(context, vertical);
      case _ToolbarGroup.fn:
        return _fnButtons(context, vertical);
    }
  }

  Widget _divider(bool vertical) =>
      vertical ? const Divider(height: 1) : const VerticalDivider(width: 1);

  List<Widget> _primaryButtons(BuildContext context, bool vertical) {
    return [
      if (widget.onSidebar != null) ...[
        _buildSidebarButton(),
        _divider(vertical),
      ],
      if (widget.onKeyboardToggle != null) _buildKeyboardButton(),
      _buildSnippetButton(),
      _divider(vertical),
      _buildKeyButton(context, 'Enter', '\r', vertical),
      _buildKeyButton(context, '\u2191', '\x1b[A', vertical),
      _buildKeyButton(context, '\u2193', '\x1b[B', vertical),
      _buildKeyButton(context, '\u2190', '\x1b[D', vertical),
      _buildKeyButton(context, '\u2192', '\x1b[C', vertical),
      _buildKeyButton(context, 'C-c', '\x03', vertical),
      _divider(vertical),
      _buildGroupButton(context, 'Keys', _ToolbarGroup.keys, vertical),
      _buildGroupButton(context, 'tmux', _ToolbarGroup.tmux, vertical),
      _buildGroupButton(context, 'Fn', _ToolbarGroup.fn, vertical),
    ];
  }

  List<Widget> _keysButtons(BuildContext context, bool vertical) {
    return [
      _buildBackButton(),
      _divider(vertical),
      _buildToggleButton(context, 'Ctrl', widget.ctrlActive, widget.onCtrlToggle, vertical),
      _buildToggleButton(context, 'Alt', widget.altActive, widget.onAltToggle, vertical),
      _buildKeyButton(context, 'Esc', '\x1b', vertical),
      _buildKeyButton(context, 'Tab', '\t', vertical),
      _buildKeyButton(context, 'S-Tab', '\x1b[Z', vertical),
    ];
  }

  List<Widget> _tmuxButtons(BuildContext context, bool vertical) {
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
      _buildBackButton(),
      _divider(vertical),
      tmuxLabel,
      _divider(vertical),
      _buildTmuxButton('c', 'c', vertical),
      _buildTmuxButton('d', 'd', vertical),
      for (final i in List.generate(10, (n) => n))
        _buildTmuxButton('$i', '$i', vertical),
      _divider(vertical),
      _buildTmuxButton('[', '[', vertical),
      _buildTmuxButton(']', ']', vertical),
      _divider(vertical),
      _buildKeyButton(context, 'PgUp', '\x1b[5~', vertical),
      _buildKeyButton(context, 'PgDn', '\x1b[6~', vertical),
    ];
  }

  List<Widget> _fnButtons(BuildContext context, bool vertical) {
    const fnKeys = <({String label, String key})>[
      (label: 'F1', key: '\x1bOP'),
      (label: 'F2', key: '\x1bOQ'),
      (label: 'F3', key: '\x1bOR'),
      (label: 'F4', key: '\x1bOS'),
      (label: 'F5', key: '\x1b[15~'),
      (label: 'F6', key: '\x1b[17~'),
      (label: 'F7', key: '\x1b[18~'),
      (label: 'F8', key: '\x1b[19~'),
      (label: 'F9', key: '\x1b[20~'),
      (label: 'F10', key: '\x1b[21~'),
      (label: 'F11', key: '\x1b[23~'),
      (label: 'F12', key: '\x1b[24~'),
    ];
    return [
      _buildBackButton(),
      _divider(vertical),
      for (final f in fnKeys) _buildKeyButton(context, f.label, f.key, vertical),
    ];
  }

  Widget _buildSidebarButton() {
    return IconButton(
      icon: const Icon(Icons.menu, size: 20),
      tooltip: 'Show sidebar',
      onPressed: widget.onSidebar,
    );
  }

  Widget _buildSnippetButton() {
    return IconButton(
      icon: const Icon(Icons.code, size: 20),
      tooltip: 'Snippets',
      onPressed: widget.onSnippets,
    );
  }

  Widget _buildKeyboardButton() {
    return IconButton(
      icon: Icon(
        widget.softKeyboardVisible ? Icons.keyboard_hide : Icons.keyboard,
        size: 20,
      ),
      tooltip: widget.softKeyboardVisible ? 'Hide keyboard' : 'Show keyboard',
      onPressed: widget.onKeyboardToggle,
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back, size: 20),
      tooltip: 'Back',
      onPressed: () => _setGroup(_ToolbarGroup.primary),
    );
  }

  Widget _buildGroupButton(BuildContext context, String label,
      _ToolbarGroup target, bool vertical) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () => _setGroup(target),
        style: TextButton.styleFrom(
          minimumSize: vertical ? const Size(48, 36) : const Size(44, 48),
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          '$label \u25b8',
          style: TextStyle(fontSize: vertical ? 12 : 13),
        ),
      ),
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
          if (widget.ctrlActive) {
            widget.onKey(_applyCtrl(key));
            widget.onCtrlToggle();
          } else if (widget.altActive) {
            widget.onKey(_applyAlt(key));
            widget.onAltToggle();
          } else {
            widget.onKey(key);
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
