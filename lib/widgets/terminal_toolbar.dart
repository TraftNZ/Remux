import 'dart:async';

import 'package:flutter/material.dart';

import '../services/terminal_mouse.dart';

enum _ToolbarGroup { primary, navigation, keys, tmux, fn }

class TerminalToolbar extends StatefulWidget {
  final void Function(String key) onKey;
  final VoidCallback onSnippets;
  final VoidCallback onCopy;
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
    required this.onCopy,
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
  // While a scroll button is held, the sequence is re-sent on this interval
  // so the pane keeps scrolling until the finger lifts.
  static const Duration _scrollRepeatInterval = Duration(milliseconds: 120);

  // Page-up / page-down escape sequences, sent by the toolbar scroll buttons so
  // apps that page on these keys (Claude, pagers) can be scrolled without a
  // physical keyboard.
  static const String _pageUp = '\x1b[5~';
  static const String _pageDown = '\x1b[6~';

  _ToolbarGroup _group = _ToolbarGroup.primary;
  Timer? _scrollTimer;

  void _toggleGroup(_ToolbarGroup group) => setState(() {
    _group = _group == group ? _ToolbarGroup.primary : group;
  });

  void _startScroll(String seq) {
    widget.onKey(seq); // fire once immediately for a responsive first scroll
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(
      _scrollRepeatInterval,
      (_) => widget.onKey(seq),
    );
  }

  void _stopScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.vertical
        ? _buildVertical(context)
        : _buildHorizontal(context);
  }

  Widget _buildHorizontal(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_group != _ToolbarGroup.primary)
            _buildButtonBar(
              context,
              _submenuButtons(context, false),
              false,
              _group.name,
            ),
          _buildButtonBar(
            context,
            _primaryButtons(context, false),
            false,
            'primary',
          ),
        ],
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_group != _ToolbarGroup.primary)
          _buildButtonBar(
            context,
            _submenuButtons(context, true),
            true,
            _group.name,
          ),
        _buildButtonBar(
          context,
          _primaryButtons(context, true),
          true,
          'primary',
        ),
      ],
    );
  }

  Widget _buildButtonBar(
    BuildContext context,
    List<Widget> buttons,
    bool vertical,
    String name,
  ) {
    return Container(
      key: ValueKey('$name-${vertical ? 'vertical' : 'horizontal'}'),
      width: vertical ? 56 : double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
        child: vertical ? Column(children: buttons) : Row(children: buttons),
      ),
    );
  }

  List<Widget> _submenuButtons(BuildContext context, bool vertical) {
    switch (_group) {
      case _ToolbarGroup.primary:
        return [];
      case _ToolbarGroup.navigation:
        return _navigationButtons(context, vertical);
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
      _buildCopyButton(),
      _divider(vertical),
      _buildKeyButton(context, 'Enter', '\r', vertical),
      _buildKeyButton(context, 'C-c', '\x03', vertical),
      _divider(vertical),
      _buildGroupButton(context, 'Nav', _ToolbarGroup.navigation, vertical),
      _buildGroupButton(context, 'Keys', _ToolbarGroup.keys, vertical),
      _buildGroupButton(context, 'tmux', _ToolbarGroup.tmux, vertical),
      _buildGroupButton(context, 'Fn', _ToolbarGroup.fn, vertical),
    ];
  }

  List<Widget> _navigationButtons(BuildContext context, bool vertical) {
    return [
      _buildKeyButton(context, '\u2191', '\x1b[A', vertical),
      _buildKeyButton(context, '\u2193', '\x1b[B', vertical),
      _buildKeyButton(context, '\u2190', '\x1b[D', vertical),
      _buildKeyButton(context, '\u2192', '\x1b[C', vertical),
      if (vertical) _divider(vertical),
      _buildScrollButton(context, '🖱↑', mouseWheelUp, 'Scroll up', vertical),
      _buildScrollButton(
        context,
        '🖱↓',
        mouseWheelDown,
        'Scroll down',
        vertical,
      ),
      _buildScrollButton(context, 'PgUp', _pageUp, 'Page up', vertical),
      _buildScrollButton(context, 'PgDn', _pageDown, 'Page down', vertical),
    ];
  }

  List<Widget> _keysButtons(BuildContext context, bool vertical) {
    return [
      _buildToggleButton(
        context,
        'Ctrl',
        widget.ctrlActive,
        widget.onCtrlToggle,
        vertical,
      ),
      _buildToggleButton(
        context,
        'Alt',
        widget.altActive,
        widget.onAltToggle,
        vertical,
      ),
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
      tmuxLabel,
      if (vertical) _divider(vertical),
      _buildTmuxButton('c', 'c', vertical),
      _buildTmuxButton('d', 'd', vertical),
      for (final i in List.generate(10, (n) => n))
        _buildTmuxButton('$i', '$i', vertical),
      if (vertical) _divider(vertical),
      _buildTmuxButton('[', '[', vertical),
      _buildTmuxButton(']', ']', vertical),
      if (vertical) _divider(vertical),
      _buildKeyButton(context, 'PgUp', _pageUp, vertical),
      _buildKeyButton(context, 'PgDn', _pageDown, vertical),
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
      for (final f in fnKeys)
        _buildKeyButton(context, f.label, f.key, vertical),
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

  Widget _buildCopyButton() {
    return IconButton(
      icon: const Icon(Icons.content_copy, size: 20),
      tooltip: 'Copy selection',
      onPressed: widget.onCopy,
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

  Widget _buildGroupButton(
    BuildContext context,
    String label,
    _ToolbarGroup target,
    bool vertical,
  ) {
    final active = _group == target;
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () => _toggleGroup(target),
        style: TextButton.styleFrom(
          backgroundColor: active
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          minimumSize: vertical ? const Size(48, 36) : const Size(44, 48),
          padding: vertical
              ? const EdgeInsets.symmetric(vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(
          '$label ${active ? '\u25be' : '\u25b8'}',
          style: TextStyle(fontSize: vertical ? 12 : 13),
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onToggle,
    bool vertical,
  ) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onToggle,
        style: TextButton.styleFrom(
          backgroundColor: active
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
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

  Widget _buildScrollButton(
    BuildContext context,
    String label,
    String seq,
    String tooltip,
    bool vertical,
  ) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Listener(
          onPointerDown: (_) => _startScroll(seq),
          onPointerUp: (_) => _stopScroll(),
          onPointerCancel: (_) => _stopScroll(),
          child: TextButton(
            // Pointer events drive the scroll; keep an empty handler so the
            // button still renders enabled and shows a tap ripple.
            onPressed: () {},
            style: TextButton.styleFrom(
              minimumSize: vertical ? const Size(48, 36) : const Size(44, 48),
              padding: vertical
                  ? const EdgeInsets.symmetric(vertical: 4)
                  : const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(label, style: TextStyle(fontSize: vertical ? 12 : 13)),
          ),
        ),
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
    BuildContext context,
    String label,
    String key,
    bool vertical,
  ) {
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
        child: Text(label, style: TextStyle(fontSize: vertical ? 12 : 13)),
      ),
    );
  }
}
