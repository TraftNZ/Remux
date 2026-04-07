// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Identity _$IdentityFromJson(Map<String, dynamic> json) => Identity(
  id: json['id'] as String,
  name: json['name'] as String,
  username: json['username'] as String,
  authType: $enumDecode(_$AuthTypeEnumMap, json['authType']),
);

Map<String, dynamic> _$IdentityToJson(Identity instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'username': instance.username,
  'authType': _$AuthTypeEnumMap[instance.authType]!,
};

const _$AuthTypeEnumMap = {AuthType.password: 'password', AuthType.key: 'key'};
