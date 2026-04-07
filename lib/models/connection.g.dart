// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Connection _$ConnectionFromJson(Map<String, dynamic> json) => Connection(
  id: json['id'] as String,
  name: json['name'] as String,
  host: json['host'] as String,
  port: (json['port'] as num?)?.toInt() ?? 22,
  type:
      $enumDecodeNullable(_$ConnectionTypeEnumMap, json['type']) ??
      ConnectionType.ssh,
  identityId: json['identityId'] as String?,
  tmuxSession: json['tmuxSession'] as String?,
  startupCommand: json['startupCommand'] as String?,
  group: json['group'] as String?,
);

Map<String, dynamic> _$ConnectionToJson(Connection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'host': instance.host,
      'port': instance.port,
      'type': _$ConnectionTypeEnumMap[instance.type]!,
      'identityId': instance.identityId,
      'tmuxSession': instance.tmuxSession,
      'startupCommand': instance.startupCommand,
      'group': instance.group,
    };

const _$ConnectionTypeEnumMap = {
  ConnectionType.ssh: 'ssh',
  ConnectionType.mosh: 'mosh',
};
