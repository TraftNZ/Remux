import 'package:json_annotation/json_annotation.dart';

import 'port_forward.dart';

part 'connection.g.dart';

enum ConnectionType { ssh, mosh }

@JsonSerializable(explicitToJson: true)
class Connection {
  final String id;
  final String name;
  final String host;
  final int port;
  final ConnectionType type;
  final String? identityId;
  final String? tmuxSession;
  final String? startupCommand;
  final String? group;

  /// Id of another [Connection] used as an SSH bridge (jump host). The tunnel
  /// is opened through that connection instead of dialing [host] directly.
  /// Chains are supported — the jump host may itself define a [jumpHostId].
  final String? jumpHostId;

  /// Tunnels opened on this session so local apps can reach remote ports (and
  /// vice versa). SSH only — see [PortForward].
  final List<PortForward> portForwards;

  const Connection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    this.type = ConnectionType.ssh,
    this.identityId,
    this.tmuxSession,
    this.startupCommand,
    this.group,
    this.jumpHostId,
    this.portForwards = const [],
  });

  Connection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    ConnectionType? type,
    Object? identityId = _sentinel,
    Object? tmuxSession = _sentinel,
    Object? startupCommand = _sentinel,
    Object? group = _sentinel,
    Object? jumpHostId = _sentinel,
    List<PortForward>? portForwards,
  }) {
    return Connection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      type: type ?? this.type,
      identityId: identityId == _sentinel ? this.identityId : identityId as String?,
      tmuxSession: tmuxSession == _sentinel ? this.tmuxSession : tmuxSession as String?,
      startupCommand: startupCommand == _sentinel ? this.startupCommand : startupCommand as String?,
      group: group == _sentinel ? this.group : group as String?,
      jumpHostId: jumpHostId == _sentinel ? this.jumpHostId : jumpHostId as String?,
      portForwards: portForwards ?? this.portForwards,
    );
  }

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionToJson(this);
}

// Sentinel value for copyWith nullable fields
const _sentinel = Object();
