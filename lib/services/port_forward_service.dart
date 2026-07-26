import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/port_forward.dart';

/// Local forwards bind loopback only — binding all interfaces would expose the
/// tunnel to every machine on the network.
const _localBindAddress = '127.0.0.1';

/// An empty bind address lets the SSH server apply its own `GatewayPorts`
/// policy for remote forwards (loopback unless the admin opened it up).
const _remoteBindAddress = '';

/// A tunnel that is currently running on an SSH session.
///
/// Created by [startPortForward]; closed by the session on disconnect.
class ActivePortForward {
  final PortForward config;

  final ServerSocket? _server;
  final SSHRemoteForward? _remoteForward;
  final StreamSubscription<void> _subscription;
  final List<Socket> _sockets = [];

  ActivePortForward._({
    required this.config,
    required StreamSubscription<void> subscription,
    ServerSocket? server,
    SSHRemoteForward? remoteForward,
  })  : _subscription = subscription,
        _server = server,
        _remoteForward = remoteForward;

  /// Stops accepting new connections and drops the ones still open.
  Future<void> close() async {
    await _subscription.cancel();
    _remoteForward?.close();
    for (final socket in [..._sockets]) {
      socket.destroy();
    }
    _sockets.clear();
    await _server?.close();
  }

  void _track(Socket socket) {
    _sockets.add(socket);
    unawaited(socket.done.whenComplete(() => _sockets.remove(socket)));
  }
}

/// Opens [config] on [client].
///
/// Throws [SocketException] if a local port cannot be bound, or [StateError] if
/// the SSH server refuses to bind a remote port (already in use, or blocked by
/// its `AllowTcpForwarding` policy).
Future<ActivePortForward> startPortForward(
  SSHClient client,
  PortForward config,
) async {
  return switch (config.type) {
    PortForwardType.local => _startLocal(client, config),
    PortForwardType.remote => _startRemote(client, config),
  };
}

Future<ActivePortForward> _startLocal(
  SSHClient client,
  PortForward config,
) async {
  final server = await ServerSocket.bind(_localBindAddress, config.listenPort);
  late final ActivePortForward forward;
  final subscription = server.listen((socket) async {
    forward._track(socket);
    try {
      final channel =
          await client.forwardLocal(config.targetHost, config.targetPort);
      _pipe(socket, channel);
    } catch (_) {
      socket.destroy();
    }
  });
  forward = ActivePortForward._(
    config: config,
    subscription: subscription,
    server: server,
  );
  return forward;
}

Future<ActivePortForward> _startRemote(
  SSHClient client,
  PortForward config,
) async {
  final remoteForward = await client.forwardRemote(
    host: _remoteBindAddress,
    port: config.listenPort,
  );
  if (remoteForward == null) {
    throw StateError('server refused to listen on port ${config.listenPort}');
  }
  late final ActivePortForward forward;
  final subscription = remoteForward.connections.listen((channel) async {
    try {
      final socket = await Socket.connect(config.targetHost, config.targetPort);
      forward._track(socket);
      _pipe(socket, channel);
    } catch (_) {
      channel.destroy();
    }
  });
  forward = ActivePortForward._(
    config: config,
    subscription: subscription,
    remoteForward: remoteForward,
  );
  return forward;
}

/// Couples a TCP socket to an SSH channel in both directions. Each `pipe`
/// closes its destination when the source ends, so a half-close on either side
/// tears the pair down; errors just drop the connection.
void _pipe(Socket socket, SSHForwardChannel channel) {
  unawaited(
    socket.cast<List<int>>().pipe(channel.sink).catchError((_) {
      channel.destroy();
    }),
  );
  unawaited(
    channel.stream.cast<List<int>>().pipe(socket).catchError((_) {
      socket.destroy();
    }),
  );
}
