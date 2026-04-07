import 'package:json_annotation/json_annotation.dart';

part 'connection.g.dart';

enum ConnectionType { ssh, mosh }

@JsonSerializable()
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
    );
  }

  factory Connection.fromJson(Map<String, dynamic> json) =>
      _$ConnectionFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionToJson(this);
}

// Sentinel value for copyWith nullable fields
const _sentinel = Object();
