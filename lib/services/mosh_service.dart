import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../models/mosh_dart_session.dart';
import '../models/mosh_session.dart';
import '../models/terminal_session.dart';
import 'mosh_dart_service.dart';

class MoshService {
  final MoshDartService _dartService = MoshDartService();

  bool get _useDartImpl => Platform.isIOS || Platform.isAndroid;

  /// Returns true if the mosh binary is available in PATH.
  Future<bool> isMoshAvailable() async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['mosh'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<TerminalSession> connect({
    required Connection connection,
    required Identity identity,
    Terminal? existingTerminal,
  }) async {
    if (_useDartImpl) {
      return _dartService.connect(
        connection: connection,
        identity: identity,
        existingTerminal: existingTerminal,
      );
    }
    final terminal = existingTerminal ?? Terminal(maxLines: 10000);

    // Build SSH options for mosh's inner SSH connection
    File? tempKeyFile;
    final sshArgs = <String>['ssh'];

    if (identity.privateKey != null) {
      tempKeyFile = File(
        '${Directory.systemTemp.path}/remux_key_${DateTime.now().millisecondsSinceEpoch}',
      );
      final keyContent = identity.privateKey!.endsWith('\n')
          ? identity.privateKey!
          : '${identity.privateKey!}\n';
      await tempKeyFile.writeAsString(keyContent);
      await Process.run('chmod', ['600', tempKeyFile.path]);
      sshArgs.addAll(['-i', tempKeyFile.path]);
    }
    sshArgs.addAll(['-o', 'StrictHostKeyChecking=accept-new']);

    // Use flutter_pty so mosh gets a real PTY (required for tcgetattr)
    final pty = Pty.start(
      'mosh',
      arguments: [
        '--ssh=${sshArgs.join(' ')}',
        '${identity.username}@${connection.host}',
      ],
      environment: {
        'TERM': 'xterm-256color',
        if (Platform.environment['SSH_AUTH_SOCK'] != null)
          'SSH_AUTH_SOCK': Platform.environment['SSH_AUTH_SOCK']!,
        if (Platform.environment['HOME'] != null)
          'HOME': Platform.environment['HOME']!,
        if (Platform.environment['PATH'] != null)
          'PATH': Platform.environment['PATH']!,
      },
    );

    final session = MoshSession(
      pty: pty,
      connection: connection,
      terminal: terminal,
      terminalAlreadyReady: existingTerminal != null,
    );

    pty.output.listen((data) {
      session.writeToTerminal(String.fromCharCodes(data));
    });

    terminal.onOutput = (data) {
      pty.write(Uint8List.fromList(data.codeUnits));
    };

    terminal.onResize = (w, h, pw, ph) => pty.resize(h, w);

    // Sync the freshly-started PTY to the Terminal's current view size before
    // the delayed tmux-attach runs. On reconnect existingTerminal is already
    // laid out at the widget's real size and terminal.onResize won't fire
    // again; without this, tmux would attach at the flutter_pty default and
    // draw only to that smaller size forever, leaving a large blank gap
    // beneath tmux's last row inside the larger TerminalView.
    pty.resize(terminal.viewHeight, terminal.viewWidth);

    pty.exitCode.then((_) async {
      session.isConnected = false;
      if (tempKeyFile != null) {
        try { await tempKeyFile.delete(); } catch (e) { /* ignore */ }
      }
    });

    if (connection.tmuxSession != null && connection.tmuxSession!.isNotEmpty) {
      final safeName =
          connection.tmuxSession!.replaceAll(RegExp(r'[^\w\-]'), '');
      if (safeName.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 800), () {
          pty.write(Uint8List.fromList(utf8.encode(
            'tmux attach-session -t $safeName || tmux new-session -s $safeName\n',
          )));
        });
      }
    }

    return session;
  }

  void disconnect(TerminalSession session) {
    if (session is MoshDartSession) {
      _dartService.disconnect(session);
      return;
    }
    if (session is MoshSession) {
      session.dispose();
    }
  }
}
