import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import 'connection.dart';
import 'terminal_session.dart';

class MoshSession extends TerminalSession {
  final Pty pty;
  final Connection connection;
  @override
  final Terminal terminal;

  bool _terminalReady;
  final List<String> _pendingWrites = [];

  MoshSession({
    required this.pty,
    required this.connection,
    required this.terminal,
    bool terminalAlreadyReady = false,
  })  : _terminalReady = terminalAlreadyReady,
        super(isConnected: true, isReconnecting: false, reconnectAttempts: 0);

  @override
  String get sessionId => 'mosh_${connection.id}';

  @override
  String get displayName => connection.name;

  @override
  void writeToTerminal(String data) {
    if (_terminalReady) {
      try { terminal.write(data); } catch (_) {}
    } else {
      _pendingWrites.add(data);
    }
  }

  @override
  void markTerminalReady() {
    if (_terminalReady) return;
    _terminalReady = true;
    for (final data in _pendingWrites) {
      try { terminal.write(data); } catch (_) {}
    }
    _pendingWrites.clear();
  }

  @override
  void dispose() {
    try {
      pty.kill();
    } catch (_) {}
    isConnected = false;
  }
}
