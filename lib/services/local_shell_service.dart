import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import '../models/local_session.dart';
import 'terminal_enter.dart';

class LocalShellService {
  LocalSession connect({Terminal? existingTerminal}) {
    final shell = Platform.isWindows
        ? 'cmd.exe'
        : (Platform.environment['SHELL'] ?? 'bash');

    final terminal = existingTerminal ?? Terminal(maxLines: 10000);

    final pty = Pty.start(
      shell,
      environment: {
        'TERM': 'xterm-256color',
        'COLORTERM': 'truecolor',
        if (Platform.environment['HOME'] != null)
          'HOME': Platform.environment['HOME']!,
        if (Platform.environment['USER'] != null)
          'USER': Platform.environment['USER']!,
        if (Platform.environment['PATH'] != null)
          'PATH': Platform.environment['PATH']!,
      },
    );

    final session = LocalSession(
      pty: pty,
      terminal: terminal,
      terminalAlreadyReady: existingTerminal != null,
    );

    pty.output.listen((data) {
      session.writeToTerminal(String.fromCharCodes(data));
    });

    pty.exitCode.then((_) {
      session.isConnected = false;
    });

    // Normalize soft-keyboard Enter so TUIs see '\r' like hardware Enter.
    terminal.onOutput = (data) =>
        pty.write(Uint8List.fromList(normalizeSoftEnter(data).codeUnits));
    terminal.onResize = (width, height, pw, ph) => pty.resize(height, width);

    return session;
  }

  void disconnect(LocalSession session) {
    session.dispose();
  }
}
