import 'package:json_annotation/json_annotation.dart';

part 'snippet.g.dart';

@JsonSerializable()
class Snippet {
  final String id;
  final String name;
  final String command;
  final String? group;

  const Snippet({
    required this.id,
    required this.name,
    required this.command,
    this.group,
  });

  Snippet copyWith({
    String? id,
    String? name,
    String? command,
    String? group,
  }) {
    return Snippet(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      group: group ?? this.group,
    );
  }

  factory Snippet.fromJson(Map<String, dynamic> json) =>
      _$SnippetFromJson(json);

  Map<String, dynamic> toJson() => _$SnippetToJson(this);
}
