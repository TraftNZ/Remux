import 'package:json_annotation/json_annotation.dart';

part 'identity.g.dart';

enum AuthType {
  @JsonValue('password')
  password,
  @JsonValue('key')
  key,
}

@JsonSerializable()
class Identity {
  final String id;
  final String name;
  final String username;
  final AuthType authType;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? password;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? privateKey;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? passphrase;

  const Identity({
    required this.id,
    required this.name,
    required this.username,
    required this.authType,
    this.password,
    this.privateKey,
    this.passphrase,
  });

  Identity copyWith({
    String? id,
    String? name,
    String? username,
    AuthType? authType,
    String? password,
    String? privateKey,
    String? passphrase,
  }) {
    return Identity(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
    );
  }

  factory Identity.fromJson(Map<String, dynamic> json) =>
      _$IdentityFromJson(json);

  Map<String, dynamic> toJson() => _$IdentityToJson(this);
}
