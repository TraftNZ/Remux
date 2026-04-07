import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../models/session.dart';

class SshService {
  Future<SshSessionState> connect({
    required Connection connection,
    required Identity identity,
    void Function(SshSessionState)? onDisconnected,
    Terminal? existingTerminal,
    int termWidth = 80,
    int termHeight = 24,
  }) async {
    final client = SSHClient(
      await SSHSocket.connect(connection.host, connection.port),
      username: identity.username,
      onPasswordRequest: identity.password != null
          ? () => identity.password!
          : null,
      identities: identity.privateKey != null
          ? [
              ...SSHKeyPair.fromPem(
                identity.privateKey!,
                identity.passphrase,
              ),
            ]
          : null,
    );

    final shell = await client.shell(
      pty: SSHPtyConfig(
        width: termWidth,
        height: termHeight,
      ),
    );

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

    // Pipe terminal user input → remote stdin
    terminal.onOutput = (data) {
      shell.write(utf8.encode(data));
    };

    // Sync terminal resize to remote PTY
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      shell.resizeTerminal(width, height);
    };

    // Auto-attach to tmux session if configured
    if (connection.tmuxSession != null && connection.tmuxSession!.isNotEmpty) {
      final safeName =
          connection.tmuxSession!.replaceAll(RegExp(r'[^\w\-]'), '');
      if (safeName.isNotEmpty) {
        shell.write(utf8.encode(
          'tmux attach-session -t $safeName || tmux new-session -s $safeName\n',
        ));
      }
    } else if (connection.startupCommand != null &&
        connection.startupCommand!.isNotEmpty) {
      shell.write(utf8.encode('${connection.startupCommand}\n'));
    }

    // Notify provider when shell exits so it can trigger auto-reconnect
    shell.done.then((_) {
      session.isConnected = false;
      onDisconnected?.call(session);
    });

    return session;
  }

  void sendSnippet(SshSessionState session, String command) {
    session.shell.write(utf8.encode('$command\n'));
  }

  void disconnect(SshSessionState session) {
    session.dispose();
  }
}
