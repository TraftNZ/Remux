import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import 'terminal_session.dart';

class LocalSession extends TerminalSession {
  final Pty pty;
  @override
  final Terminal terminal;

  bool _terminalReady;
  final List<String> _pendingWrites = [];

  LocalSession({
    required this.pty,
    required this.terminal,
    bool terminalAlreadyReady = false,
  })  : _terminalReady = terminalAlreadyReady,
        super(isConnected: true, isReconnecting: false, reconnectAttempts: 0);

  @override
  String get sessionId => 'local_${terminal.hashCode}';

  @override
  String get displayName => 'Local Shell';

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
    pty.kill();
    isConnected = false;
  }
}
