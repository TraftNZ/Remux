// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snippet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Snippet _$SnippetFromJson(Map<String, dynamic> json) => Snippet(
  id: json['id'] as String,
  name: json['name'] as String,
  command: json['command'] as String,
  group: json['group'] as String?,
);

Map<String, dynamic> _$SnippetToJson(Snippet instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'command': instance.command,
  'group': instance.group,
};
