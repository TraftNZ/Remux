import 'dart:async';
import 'dart:io';

import 'package:mosh_dart/mosh_pb.dart';
import 'package:mosh_dart/mosh_transport.dart';
import 'package:xterm/xterm.dart';

import 'connection.dart';
import 'terminal_session.dart';

const Duration _kTickInterval = Duration(milliseconds: 8);

class MoshDartSession extends TerminalSession {
  final Connection connection;
  @override
  final Terminal terminal;
  final RawDatagramSocket socket;
  final MoshTransport transport;
  final InternetAddress serverAddress;
  final int moshPort;
  final List<UserInstruction> pendingKeys = <UserInstruction>[];

  Timer? _tickTimer;
  bool _terminalReady;
  final List<String> _pendingWrites = <String>[];

  MoshDartSession({
    required this.connection,
    required this.terminal,
    required this.socket,
    required this.transport,
    required this.serverAddress,
    required this.moshPort,
    bool terminalAlreadyReady = false,
  })  : _terminalReady = terminalAlreadyReady,
        super(isConnected: true, isReconnecting: false, reconnectAttempts: 0);

  @override
  String get sessionId => 'mosh_dart_${connection.id}';

  @override
  String get displayName => connection.name;

  void startTick() {
    _tickTimer ??= Timer.periodic(_kTickInterval, (_) => _onTick());
  }

  void _onTick() {
    // Only send a new state when the previous one has been acked.
    if (!transport.hasPendingState && pendingKeys.isNotEmpty) {
      final batch = List<UserInstruction>.from(pendingKeys);
      pendingKeys.clear();
      try {
        final diff = marshalUserMessage(batch);
        transport.sendNew(diff);
      } catch (_) {}
    }
    try {
      final datagrams = transport.tick();
      for (final dg in datagrams) {
        socket.send(dg, serverAddress, moshPort);
      }
    } catch (_) {}
  }

  @override
  void writeToTerminal(String data) {
    if (_terminalReady) {
      try {
        terminal.write(data);
      } catch (_) {}
    } else {
      _pendingWrites.add(data);
    }
  }

  @override
  void markTerminalReady() {
    if (_terminalReady) return;
    _terminalReady = true;
    for (final data in _pendingWrites) {
      try {
        terminal.write(data);
      } catch (_) {}
    }
    _pendingWrites.clear();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tickTimer = null;
    try {
      socket.close();
    } catch (_) {}
    isConnected = false;
  }
}
