@TestOn('mac-os || linux')
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mosh_dart/mosh_pb.dart';
import 'package:mosh_dart/mosh_transport.dart';
import 'package:mosh_dart/ocb.dart';
import 'package:test/test.dart';

String repr(String s) =>
    s.replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\x1b', '\\e');

class MoshTestClient {
  late RawDatagramSocket socket;
  late MoshTransport transport;
  late int moshPort;
  final _diffs = StreamController<Uint8List>.broadcast();
  StreamSubscription? _sub;
  Timer? _ticker;

  // Single-state-at-a-time keystroke queue.
  final pendingKeys = <UserInstruction>[];

  Stream<Uint8List> get diffs => _diffs.stream;

  Future<void> start() async {
    final result = await Process.run('mosh-server', [
      'new', '-s', '-c', '256', '-l', 'LANG=en_US.UTF-8', '--', '/bin/sh',
    ]);
    final output = result.stdout.toString() + result.stderr.toString();
    final match = RegExp(r'MOSH CONNECT (\d+) ([A-Za-z0-9/+]+={0,2})')
        .firstMatch(output);
    if (match == null) fail('mosh-server did not output MOSH CONNECT:\n$output');

    moshPort = int.parse(match.group(1)!);
    var keyStr = match.group(2)!;
    while (keyStr.length % 4 != 0) keyStr += '=';
    final moshKey = base64Decode(keyStr);

    socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final ocb = AesOcb(moshKey);
    transport = MoshTransport.client(ocb);

    _sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      try {
        final diff = transport.recv(Uint8List.fromList(dg.data));
        if (diff != null && diff.isNotEmpty) _diffs.add(diff);
      } catch (_) {}
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 8), (_) => flush());
  }

  void flush() {
    if (!transport.hasPendingState && pendingKeys.isNotEmpty) {
      transport.sendNew(marshalUserMessage(pendingKeys));
      pendingKeys.clear();
    }
    for (final dg in transport.tick()) {
      socket.send(dg, InternetAddress.loopbackIPv4, moshPort);
    }
  }

  Future<List<Uint8List>> collectDiffs(Duration timeout) async {
    final collected = <Uint8List>[];
    final completer = Completer<List<Uint8List>>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(collected);
    });
    final sub = diffs.listen((d) => collected.add(d));
    final result = await completer.future;
    timer.cancel();
    await sub.cancel();
    return result;
  }

  String extractText(List<Uint8List> diffs) {
    final buf = StringBuffer();
    for (final diff in diffs) {
      for (final hi in unmarshalHostMessage(diff)) {
        if (hi.hoststring != null && hi.hoststring!.isNotEmpty) {
          buf.write(utf8.decode(hi.hoststring!, allowMalformed: true));
        }
      }
    }
    return buf.toString();
  }

  Future<void> stop() async {
    _ticker?.cancel();
    await _sub?.cancel();
    _diffs.close();
    socket.close();
    Process.run('bash', ['-c', 'kill -9 \$(lsof -ti udp:$moshPort) 2>/dev/null || true']);
  }
}

void main() {
  group('mosh-server integration', () {
    late MoshTestClient client;

    setUp(() async {
      client = MoshTestClient();
      await client.start();
    });

    tearDown(() async {
      await client.stop();
    });

    test('initial handshake receives shell prompt', () async {
      client.transport.forceNextSend();
      client.flush();
      client.transport.sendNew(marshalUserMessage([
        UserInstruction(width: 80, height: 24),
      ]));
      client.flush();

      final diffs = await client.collectDiffs(const Duration(seconds: 3));
      final text = client.extractText(diffs);
      print('Initial state: ${repr(text)}');
      expect(text, contains('\$'));
    });

    test('individual keystrokes: l, s, Enter', () async {
      // Handshake.
      client.transport.forceNextSend();
      client.flush();
      client.transport.sendNew(marshalUserMessage([
        UserInstruction(width: 80, height: 24),
      ]));
      client.flush();
      await client.collectDiffs(const Duration(seconds: 2));

      // Each keystroke is a separate state, one at a time.
      print('--- Sending l ---');
      client.pendingKeys.add(UserInstruction(
          keys: Uint8List.fromList(utf8.encode('l'))));
      var diffs = await client.collectDiffs(const Duration(seconds: 2));
      print('After l: ${repr(client.extractText(diffs))}');
      expect(client.extractText(diffs), contains('l'));

      print('--- Sending s ---');
      client.pendingKeys.add(UserInstruction(
          keys: Uint8List.fromList(utf8.encode('s'))));
      diffs = await client.collectDiffs(const Duration(seconds: 2));
      print('After s: ${repr(client.extractText(diffs))}');
      expect(client.extractText(diffs), contains('s'));

      print('--- Sending Enter ---');
      client.pendingKeys.add(UserInstruction(
          keys: Uint8List.fromList([0x0d])));
      diffs = await client.collectDiffs(const Duration(seconds: 2));
      var text = client.extractText(diffs);
      print('After Enter: ${repr(text)}');
      expect(text.isNotEmpty, isTrue);
    });

    test('batched keystrokes: "ls\\r" in one state', () async {
      // Handshake.
      client.transport.forceNextSend();
      client.flush();
      client.transport.sendNew(marshalUserMessage([
        UserInstruction(width: 80, height: 24),
      ]));
      client.flush();
      await client.collectDiffs(const Duration(seconds: 2));

      // All keys queued at once — batched into one state.
      print('--- Sending "ls\\r" batched ---');
      for (final ch in 'ls\r'.split('')) {
        client.pendingKeys.add(UserInstruction(
            keys: Uint8List.fromList(utf8.encode(ch))));
      }
      final diffs = await client.collectDiffs(const Duration(seconds: 3));
      final text = client.extractText(diffs);
      print('After ls: ${repr(text)}');
      expect(text, contains('ls'));
    });
  });
}
