import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../services/port_forward_service.dart';
import 'connection.dart';
import 'identity.dart';
import 'terminal_session.dart';

class SshSessionState extends TerminalSession {
  final String connectionId;
  final String connectionName;
  final Connection connection;
  final Identity identity;
  final SSHClient client;

  /// Bridge (jump host) clients this session is tunnelled through, outermost
  /// first. Empty for a direct connection. Closed in reverse on dispose.
  final List<SSHClient> jumpClients;

  final SSHSession shell;
  @override
  final Terminal terminal;

  /// Tunnels running on this session, started from
  /// [Connection.portForwards]. Closed on dispose.
  final List<ActivePortForward> portForwards = [];

  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;

  bool _terminalReady;
  final List<String> _pendingWrites = [];

  SshSessionState({
    required this.connectionId,
    required this.connectionName,
    required this.connection,
    required this.identity,
    required this.client,
    this.jumpClients = const [],
    required this.shell,
    required this.terminal,
    super.isConnected = true,
    bool terminalAlreadyReady = false,
  })  : _terminalReady = terminalAlreadyReady,
        super(isReconnecting: false, reconnectAttempts: 0);

  @override
  String get sessionId => connectionId;

  @override
  String get displayName => connectionName;

  void setSubscriptions({
    required StreamSubscription<List<int>> stdout,
    required StreamSubscription<List<int>> stderr,
  }) {
    _stdoutSubscription = stdout;
    _stderrSubscription = stderr;
  }

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
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    for (final forward in portForwards) {
      unawaited(forward.close());
    }
    portForwards.clear();
    shell.close();
    client.close();
    for (final jump in jumpClients.reversed) {
      jump.close();
    }
    isConnected = false;
  }
}
