import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../models/session.dart';
import 'port_forward_service.dart';
import 'terminal_enter.dart';

/// One hop of a jump-host (bridge) chain: the bridge machine plus the
/// credentials used to authenticate to it.
class SshHop {
  final Connection connection;
  final Identity identity;

  const SshHop({required this.connection, required this.identity});
}

/// Walks [connection]'s `jumpHostId` chain and returns the bridge hops in dial
/// order (outermost bridge first, the one adjacent to the target last).
///
/// Throws [StateError] if a bridge is missing, has no usable identity, or the
/// chain loops back on itself.
List<SshHop> resolveJumpHosts(
  Connection connection,
  List<Connection> connections,
  List<Identity> identities,
) {
  if (connection.jumpHostId == null) return const [];

  final hops = <SshHop>[];
  final visited = <String>{connection.id};
  var jumpHostId = connection.jumpHostId;

  while (jumpHostId != null) {
    if (!visited.add(jumpHostId)) {
      throw StateError('Jump host chain for "${connection.name}" is circular');
    }
    final bridge = connections.where((c) => c.id == jumpHostId).firstOrNull;
    if (bridge == null) {
      throw StateError('Jump host for "${connection.name}" no longer exists');
    }
    final identity =
        identities.where((i) => i.id == bridge.identityId).firstOrNull;
    if (identity == null) {
      throw StateError('No identity assigned to jump host "${bridge.name}"');
    }
    hops.add(SshHop(connection: bridge, identity: identity));
    jumpHostId = bridge.jumpHostId;
  }

  // Collected target-first; dial from the outermost bridge inwards.
  return hops.reversed.toList();
}

class SshService {
  /// Opens a shell on [connection].
  ///
  /// When [jumpHosts] is non-empty the target is reached through those bridge
  /// machines in order: hop 0 is dialed directly, each subsequent hop (and
  /// finally [connection]) is reached over a `direct-tcpip` channel forwarded
  /// by the previous hop — the equivalent of OpenSSH's `ProxyJump`.
  Future<SshSessionState> connect({
    required Connection connection,
    required Identity identity,
    List<SshHop> jumpHosts = const [],
    void Function(SshSessionState)? onDisconnected,
    Terminal? existingTerminal,
    int termWidth = 80,
    int termHeight = 24,
  }) async {
    // Half-open state must not leak if any hop, auth, or the shell fails:
    // tear the chain down from the target backwards.
    final jumpClients = <SSHClient>[];
    final SSHClient client;
    final SSHSession shell;
    try {
      client = _createClient(
        await _openSocket(connection, jumpHosts, jumpClients),
        identity,
      );
      try {
        shell = await client.shell(
          pty: SSHPtyConfig(
            width: termWidth,
            height: termHeight,
          ),
        );
      } catch (_) {
        client.close();
        rethrow;
      }
    } catch (_) {
      for (final hop in jumpClients.reversed) {
        hop.close();
      }
      rethrow;
    }

    // Reuse existing Terminal on reconnect to preserve scrollback history.
    final terminal = existingTerminal ?? Terminal(maxLines: 10000);

    // Create session first so stream listeners can call session.writeToTerminal.
    // On reconnect, terminal is already laid out — skip buffering.
    final session = SshSessionState(
      connectionId: connection.id,
      connectionName: connection.name,
      connection: connection,
      identity: identity,
      client: client,
      jumpClients: jumpClients,
      shell: shell,
      terminal: terminal,
      terminalAlreadyReady: existingTerminal != null,
    );

    // Pipe remote stdout/stderr → terminal (buffered until ready)
    final stdoutSub = shell.stdout.listen(
      (data) {
        try {
          session.writeToTerminal(utf8.decode(data, allowMalformed: true));
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );
    final stderrSub = shell.stderr.listen(
      (data) {
        try {
          session.writeToTerminal(utf8.decode(data, allowMalformed: true));
        } catch (_) {}
      },
      onError: (_) {},
      cancelOnError: false,
    );

    session.setSubscriptions(stdout: stdoutSub, stderr: stderrSub);

    // Pipe terminal user input → remote stdin.
    // Normalize soft-keyboard Enter ('\n' / '\r\n') to '\r' so IME Enter
    // behaves like hardware Enter; see [normalizeSoftEnter]. Set here (not
    // in a post-frame callback) so the mapping survives reconnects.
    terminal.onOutput = (data) {
      shell.write(utf8.encode(normalizeSoftEnter(data)));
    };

    // Sync terminal resize to remote PTY
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      shell.resizeTerminal(width, height);
    };

    // Sync the freshly-opened PTY to the Terminal's current view size BEFORE
    // any startup/tmux command runs. This matters most for reconnects: the
    // existingTerminal is already laid out at the widget's real size (e.g.
    // 100x40), but the new PTY was opened at the 80x24 default and
    // terminal.onResize won't fire on its own because the widget size hasn't
    // changed. Without this, `tmux attach-session` runs at 80x24 and tmux
    // keeps drawing to 24 rows forever, leaving a large blank area below
    // tmux's last row (same appearance as a keyboard-sized gap) inside the
    // larger TerminalView. On initial connect this is harmless — the first
    // TerminalView layout will resize again to the measured size.
    shell.resizeTerminal(terminal.viewWidth, terminal.viewHeight);

    // Auto-attach to tmux session if configured
    if (connection.tmuxSession != null && connection.tmuxSession!.isNotEmpty) {
      final safeName =
          connection.tmuxSession!.replaceAll(RegExp(r'[^\w\-]'), '');
      if (safeName.isNotEmpty) {
        // `\; set -g mouse on` chains a tmux command onto the attach/new so
        // mouse reporting is enabled at attach time (not typed into whatever
        // app is in the foreground). Without it tmux ignores the terminal's
        // scroll-wheel and toolbar wheel buttons, so the pane can't be
        // scrolled to view history.
        shell.write(utf8.encode(
          'tmux attach-session -t $safeName \\; set -g mouse on '
          '|| tmux new-session -s $safeName \\; set -g mouse on\n',
        ));
      }
    } else if (connection.startupCommand != null &&
        connection.startupCommand!.isNotEmpty) {
      shell.write(utf8.encode('${connection.startupCommand}\n'));
    }

    await _startPortForwards(session);

    // Notify provider when shell exits so it can trigger auto-reconnect
    shell.done.then((_) {
      session.isConnected = false;
      onDisconnected?.call(session);
    });

    return session;
  }

  /// Opens every tunnel configured on the session's connection, reporting the
  /// outcome of each in the terminal. A forward that cannot start (port already
  /// bound locally, server policy) must not fail the whole session — the shell
  /// is already usable at this point.
  Future<void> _startPortForwards(SshSessionState session) async {
    for (final config in session.connection.portForwards) {
      try {
        session.portForwards.add(await startPortForward(session.client, config));
        session.writeToTerminal(
          '[remux] forwarding ${config.description}\r\n',
        );
      } catch (e) {
        session.writeToTerminal(
          '[remux] port forward ${config.description} failed: $e\r\n',
        );
      }
    }
  }

  /// Dials [connection], tunnelling through [jumpHosts] when present. Every
  /// bridge client created along the way is appended to [jumpClients] so the
  /// caller can close them — on failure here, or when the session ends.
  Future<SSHSocket> _openSocket(
    Connection connection,
    List<SshHop> jumpHosts,
    List<SSHClient> jumpClients,
  ) async {
    if (jumpHosts.isEmpty) {
      return SSHSocket.connect(connection.host, connection.port);
    }

    var socket = await SSHSocket.connect(
      jumpHosts.first.connection.host,
      jumpHosts.first.connection.port,
    );
    for (var i = 0; i < jumpHosts.length; i++) {
      final hopClient = _createClient(socket, jumpHosts[i].identity);
      jumpClients.add(hopClient);
      // The last hop forwards to the final target; earlier hops forward to
      // the next bridge. forwardLocal awaits authentication internally.
      final next = i + 1 < jumpHosts.length
          ? jumpHosts[i + 1].connection
          : connection;
      socket = await hopClient.forwardLocal(next.host, next.port);
    }
    return socket;
  }

  SSHClient _createClient(SSHSocket socket, Identity identity) {
    return SSHClient(
      socket,
      username: identity.username,
      onPasswordRequest:
          identity.password != null ? () => identity.password! : null,
      identities: identity.privateKey != null
          ? [
              ...SSHKeyPair.fromPem(
                identity.privateKey!,
                identity.passphrase,
              ),
            ]
          : null,
    );
  }

  void sendSnippet(SshSessionState session, String command) {
    session.shell.write(utf8.encode('$command\n'));
  }

  void disconnect(SshSessionState session) {
    session.dispose();
  }
}
