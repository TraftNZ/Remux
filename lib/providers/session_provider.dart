import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../models/local_session.dart';
import '../models/mosh_dart_session.dart';
import '../models/mosh_session.dart';
import '../models/session.dart';
import '../models/terminal_session.dart';
import '../services/local_shell_service.dart';
import '../services/mosh_service.dart';
import '../services/ssh_service.dart';

final sshServiceProvider = Provider<SshService>((ref) => SshService());
final localShellServiceProvider =
    Provider<LocalShellService>((ref) => LocalShellService());
final moshServiceProvider = Provider<MoshService>((ref) => MoshService());

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionState {
  final List<TerminalSession> sessions;
  final int activeIndex;

  const SessionState({
    this.sessions = const [],
    this.activeIndex = 0,
  });

  TerminalSession? get activeSession =>
      sessions.isNotEmpty ? sessions[activeIndex] : null;

  SessionState copyWith({
    List<TerminalSession>? sessions,
    int? activeIndex,
  }) {
    return SessionState(
      sessions: sessions ?? this.sessions,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  // ── SSH ───────────────────────────────────────────────────────────────────

  Future<void> connect({
    required Connection connection,
    required Identity identity,
  }) async {
    final ssh = ref.read(sshServiceProvider);
    SshSessionState? session;
    try {
      session = await ssh.connect(
        connection: connection,
        identity: identity,
        onDisconnected: _onSessionDisconnected,
      );
      state = state.copyWith(
        sessions: [...state.sessions, session],
        activeIndex: state.sessions.length,
      );
      unawaited(_syncForegroundService());
    } catch (e) {
      session?.dispose();
      rethrow;
    }
  }

  // ── Local shell ───────────────────────────────────────────────────────────

  void connectLocal() {
    final session = ref.read(localShellServiceProvider).connect();
    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeIndex: state.sessions.length,
    );
    unawaited(_syncForegroundService());
  }

  // ── Mosh ─────────────────────────────────────────────────────────────────

  Future<void> connectMosh({
    required Connection connection,
    required Identity identity,
  }) async {
    final mosh = ref.read(moshServiceProvider);
    TerminalSession? session;
    try {
      session = await mosh.connect(
        connection: connection,
        identity: identity,
      );
      state = state.copyWith(
        sessions: [...state.sessions, session],
        activeIndex: state.sessions.length,
      );
      unawaited(_syncForegroundService());
    } catch (e) {
      session?.dispose();
      rethrow;
    }
  }

  // ── Common ────────────────────────────────────────────────────────────────

  void setActiveIndex(int index) {
    if (index >= 0 && index < state.sessions.length) {
      state = state.copyWith(activeIndex: index);
    }
  }

  void disconnect(int index) {
    if (index < 0 || index >= state.sessions.length) return;
    final session = state.sessions[index];
    session.dispose();
    final updated = [...state.sessions]..removeAt(index);
    final newIndex = state.activeIndex >= updated.length
        ? (updated.isEmpty ? 0 : updated.length - 1)
        : state.activeIndex;
    state = state.copyWith(sessions: updated, activeIndex: newIndex);
    unawaited(_syncForegroundService());
  }

  void sendSnippet(String command) {
    final session = state.activeSession;
    if (session == null) return;
    if (session is SshSessionState) {
      ref.read(sshServiceProvider).sendSnippet(session, command);
    } else if (session is LocalSession) {
      session.terminal.textInput('$command\n');
    } else if (session is MoshSession) {
      session.terminal.textInput('$command\n');
    } else if (session is MoshDartSession) {
      session.terminal.textInput('$command\n');
    }
  }

  /// Manual reconnect — only valid for SSH sessions.
  void reconnectNow(TerminalSession session) {
    if (session is! SshSessionState) return;
    if (session.isReconnecting) return;
    session.reconnectAttempts = 0;
    session.isReconnecting = true;
    state = state.copyWith(sessions: [...state.sessions]);
    _reconnectWithBackoff(session);
  }

  // ── Foreground service ────────────────────────────────────────────────────

  Future<void> _syncForegroundService() async {
    if (!Platform.isAndroid) return;
    final count = state.sessions.length;
    if (count == 0) {
      await FlutterForegroundTask.stopService();
      return;
    }
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    final text = count == 1 ? '1 active session' : '$count active sessions';
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Remux',
        notificationText: text,
      );
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Remux',
        notificationText: text,
      );
    }
  }

  // ── Auto-reconnect (SSH only) ─────────────────────────────────────────────

  void _onSessionDisconnected(SshSessionState session) {
    if (!state.sessions.contains(session)) return;
    session.isReconnecting = true;
    state = state.copyWith(sessions: [...state.sessions]);
    _reconnectWithBackoff(session);
  }

  Future<void> _reconnectWithBackoff(SshSessionState oldSession) async {
    while (true) {
      final delaySecs =
          min(30, pow(2, oldSession.reconnectAttempts + 1).toInt());
      await Future.delayed(Duration(seconds: delaySecs));

      if (!state.sessions.contains(oldSession)) return;

      try {
        final newSession = await ref.read(sshServiceProvider).connect(
              connection: oldSession.connection,
              identity: oldSession.identity,
              existingTerminal: oldSession.terminal,
              onDisconnected: _onSessionDisconnected,
            );

        final idx = state.sessions.indexOf(oldSession);
        if (idx == -1) {
          newSession.dispose();
          return;
        }
        final updated = [...state.sessions]..[idx] = newSession;
        final newActiveIndex = state.activeIndex >= updated.length
            ? updated.length - 1
            : state.activeIndex;
        state = state.copyWith(sessions: updated, activeIndex: newActiveIndex);
        return;
      } catch (_) {
        oldSession.reconnectAttempts++;
        if (state.sessions.contains(oldSession)) {
          state = state.copyWith(sessions: [...state.sessions]);
        }
      }
    }
  }
}
