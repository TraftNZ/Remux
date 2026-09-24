@TestOn('mac-os || linux')
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mosh_dart/mosh_pb.dart';
import 'package:mosh_dart/mosh_transport.dart';
import 'package:mosh_dart/ocb.dart';
import 'package:test/test.dart';

void main() {
  test('fast typing: single-state-at-a-time approach', () async {
    final result = await Process.run('mosh-server', [
      'new', '-s', '-c', '256', '-l', 'LANG=en_US.UTF-8', '--', '/bin/sh',
    ]);
    final output = result.stdout.toString() + result.stderr.toString();
    final match = RegExp(r'MOSH CONNECT (\d+) ([A-Za-z0-9/+]+={0,2})')
        .firstMatch(output);
    expect(match, isNotNull);

    final port = int.parse(match!.group(1)!);
    var keyStr = match.group(2)!;
    while (keyStr.length % 4 != 0) keyStr += '=';
    final key = base64Decode(keyStr);

    final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final ocb = AesOcb(key);
    final transport = MoshTransport.client(ocb);
    final addr = InternetAddress.loopbackIPv4;

    final allText = StringBuffer();
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      try {
        final diff = transport.recv(Uint8List.fromList(dg.data));
        if (diff == null || diff.isEmpty) return;
        for (final hi in unmarshalHostMessage(diff)) {
          if (hi.hoststring != null && hi.hoststring!.isNotEmpty) {
            allText.write(utf8.decode(hi.hoststring!, allowMalformed: true));
          }
        }
      } catch (_) {}
    });

    // Pending keys buffer (like MoshSession._pendingKeys).
    final pendingKeys = <UserInstruction>[];

    void flush() {
      // Single-state-at-a-time: only send new state when server caught up.
      if (!transport.hasPendingState && pendingKeys.isNotEmpty) {
        transport.sendNew(marshalUserMessage(pendingKeys));
        pendingKeys.clear();
      }
      for (final dg in transport.tick()) {
        socket.send(dg, addr, port);
      }
    }

    final ticker = Timer.periodic(const Duration(milliseconds: 8), (_) => flush());

    // Handshake.
    transport.forceNextSend();
    flush();
    transport.sendNew(marshalUserMessage([
      UserInstruction(width: 80, height: 24),
    ]));
    flush();
    await Future.delayed(const Duration(seconds: 2));

    // Type "hello world\r" rapidly — all keys queued at once.
    print('--- Fast typing "hello world\\r" ---');
    for (final ch in 'hello world\r'.split('')) {
      pendingKeys.add(UserInstruction(
          keys: Uint8List.fromList(utf8.encode(ch))));
    }

    // Wait for all responses.
    await Future.delayed(const Duration(seconds: 5));

    print('Output: ${allText.toString().replaceAll('\x1b', '\\e').replaceAll('\r', '\\r').replaceAll('\n', '\\n')}');
    expect(allText.toString(), contains('hello'));
    expect(allText.toString(), contains('world'));

    ticker.cancel();
    socket.close();
    Process.run('bash', ['-c', 'kill -9 \$(lsof -ti udp:$port) 2>/dev/null || true']);
  }, timeout: Timeout(Duration(seconds: 15)));
}
