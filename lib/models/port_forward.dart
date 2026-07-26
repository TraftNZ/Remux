import 'package:json_annotation/json_annotation.dart';

part 'port_forward.g.dart';

/// Direction of a tunnel carried over an SSH session.
enum PortForwardType {
  /// `ssh -L` — this device listens; each connection is carried to
  /// `targetHost:targetPort` as resolved by the SSH server.
  local,

  /// `ssh -R` — the SSH server listens; each connection is carried back and
  /// dialed to `targetHost:targetPort` from this device.
  remote,
}

/// A tunnel definition attached to a [Connection]. Started automatically when
/// the session connects (and again after every auto-reconnect).
@JsonSerializable()
class PortForward {
  final String id;
  final PortForwardType type;

  /// Port the listening side binds: this device for [PortForwardType.local],
  /// the SSH server for [PortForwardType.remote].
  final int listenPort;

  /// Host the tunnelled connection is finally dialed on — resolved by the SSH
  /// server for local forwards, by this device for remote forwards.
  final String targetHost;
  final int targetPort;

  const PortForward({
    required this.id,
    this.type = PortForwardType.local,
    required this.listenPort,
    this.targetHost = 'localhost',
    required this.targetPort,
  });

  /// Human-readable summary, e.g. `localhost:8080 → 127.0.0.1:80 (on server)`.
  String get description => switch (type) {
        PortForwardType.local =>
          'localhost:$listenPort → $targetHost:$targetPort (on server)',
        PortForwardType.remote =>
          'server:$listenPort → $targetHost:$targetPort (on this device)',
      };

  PortForward copyWith({
    String? id,
    PortForwardType? type,
    int? listenPort,
    String? targetHost,
    int? targetPort,
  }) {
    return PortForward(
      id: id ?? this.id,
      type: type ?? this.type,
      listenPort: listenPort ?? this.listenPort,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
    );
  }

  factory PortForward.fromJson(Map<String, dynamic> json) =>
      _$PortForwardFromJson(json);

  Map<String, dynamic> toJson() => _$PortForwardToJson(this);
}
