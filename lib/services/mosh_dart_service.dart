import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:mosh_dart/mosh_pb.dart';
import 'package:mosh_dart/mosh_transport.dart';
import 'package:mosh_dart/ocb.dart';
import 'package:xterm/xterm.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../models/mosh_dart_session.dart';

final RegExp _kMoshConnectRegex =
    RegExp(r'MOSH CONNECT (\d+) ([A-Za-z0-9/+]+={0,2})');

class MoshDartService {
  Future<MoshDartSession> connect({
    required Connection connection,
    required Identity identity,
    Terminal? existingTerminal,
  }) async {
    final terminal = existingTerminal ?? Terminal(maxLines: 10000);

    final client = SSHClient(
      await SSHSocket.connect(connection.host, connection.port),
      username: identity.username,
      onPasswordRequest:
          identity.password != null ? () => identity.password! : null,
      identities: identity.privateKey != null
          ? [
              ...SSHKeyPair.fromPem(
                identity.privateKey!,
                identity.passphrase,
              )
            ]
          : null,
    );

    final sshSession = await client.execute('mosh-server');
    final outputBuf = StringBuffer();
    String? moshLine;
    await for (final chunk in sshSession.stdout) {
      outputBuf.write(utf8.decode(chunk, allowMalformed: true));
      if (_kMoshConnectRegex.hasMatch(outputBuf.toString())) {
        moshLine = outputBuf.toString();
        break;
      }
    }
    client.close();

    final match = _kMoshConnectRegex.firstMatch(moshLine ?? '');
    if (match == null) {
      throw Exception('mosh-server did not return MOSH CONNECT line');
    }

    final moshPort = int.parse(match.group(1)!);
    var keyStr = match.group(2)!;
    while (keyStr.length % 4 != 0) {
      keyStr += '=';
    }
    final moshKey = base64Decode(keyStr);

    final ocb = AesOcb(moshKey);
    final transport = MoshTransport.client(ocb);
    final serverAddr = (await InternetAddress.lookup(connection.host)).first;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    final session = MoshDartSession(
      connection: connection,
      terminal: terminal,
      socket: socket,
      transport: transport,
      serverAddress: serverAddr,
      moshPort: moshPort,
      terminalAlreadyReady: existingTerminal != null,
    );

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final diff = transport.recv(Uint8List.fromList(dg.data));
      if (diff == null || diff.isEmpty) return;
      for (final hi in unmarshalHostMessage(diff)) {
        if (hi.hoststring != null && hi.hoststring!.isNotEmpty) {
          session.writeToTerminal(
            utf8.decode(hi.hoststring!, allowMalformed: true),
          );
        }
      }
    });

    terminal.onOutput = (data) {
      session.pendingKeys.add(
        UserInstruction(keys: Uint8List.fromList(utf8.encode(data))),
      );
    };

    terminal.onResize = (w, h, pw, ph) {
      if (w > 0 && h > 0) {
        session.pendingKeys.add(UserInstruction(width: w, height: h));
      }
    };

    // Send initial terminal size so mosh-server knows dimensions immediately
    session.pendingKeys.add(UserInstruction(width: 80, height: 24));
    session.startTick();
    transport.forceNextSend();

    if (connection.tmuxSession != null && connection.tmuxSession!.isNotEmpty) {
      final safeName =
          connection.tmuxSession!.replaceAll(RegExp(r'[^\w\-]'), '');
      if (safeName.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 800), () {
          session.pendingKeys.add(
            UserInstruction(
              keys: Uint8List.fromList(utf8.encode(
                'tmux attach-session -t $safeName || tmux new-session -s $safeName\n',
              )),
            ),
          );
        });
      }
    }

    return session;
  }

  void disconnect(MoshDartSession session) {
    session.dispose();
  }
}
