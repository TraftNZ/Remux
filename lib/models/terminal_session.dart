import 'package:xterm/xterm.dart';

/// Abstract base for all terminal session types (SSH, local shell, mosh).
abstract class TerminalSession {
  String get sessionId;
  String get displayName;
  Terminal get terminal;

  bool isConnected;
  bool isReconnecting;
  int reconnectAttempts;

  TerminalSession({
    required this.isConnected,
    required this.isReconnecting,
    required this.reconnectAttempts,
  });

  /// Write [data] to the terminal, buffering if not yet laid out.
  void writeToTerminal(String data);

  /// Flush buffered writes and enable direct writes.
  /// Called once after TerminalView is laid out.
  void markTerminalReady();

  void dispose();
}
