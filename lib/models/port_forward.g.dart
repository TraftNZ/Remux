// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'port_forward.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PortForward _$PortForwardFromJson(Map<String, dynamic> json) => PortForward(
  id: json['id'] as String,
  type:
      $enumDecodeNullable(_$PortForwardTypeEnumMap, json['type']) ??
      PortForwardType.local,
  listenPort: (json['listenPort'] as num).toInt(),
  targetHost: json['targetHost'] as String? ?? 'localhost',
  targetPort: (json['targetPort'] as num).toInt(),
);

Map<String, dynamic> _$PortForwardToJson(PortForward instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$PortForwardTypeEnumMap[instance.type]!,
      'listenPort': instance.listenPort,
      'targetHost': instance.targetHost,
      'targetPort': instance.targetPort,
    };

const _$PortForwardTypeEnumMap = {
  PortForwardType.local: 'local',
  PortForwardType.remote: 'remote',
};
