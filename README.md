# Remux

SSH terminal app for Android/iOS to manage remote compute sessions.

Features:
- Multiple concurrent SSH sessions with tab switching
- Connection management with separate identity support (update once, use everywhere)
- Auto-attach to tmux sessions
- Custom command snippets
- Secure credential storage

## Acknowledgments

Built with amazing open source packages:

- [dartssh2](https://pub.dev/packages/dartssh2) - Pure Dart SSH client
- [mosh_dart](https://pub.dev/packages/mosh_dart) - Mobile SSH (mosh) support
- [xterm](https://pub.dev/packages/xterm) - Terminal emulator widget
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) - State management
- [go_router](https://pub.dev/packages/go_router) - Navigation
- [path_provider](https://pub.dev/packages/path_provider) - File system paths
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) - Encrypted credential storage
- [uuid](https://pub.dev/packages/uuid) - UUID generation
- [json_annotation](https://pub.dev/packages/json_annotation) - JSON serialization
- [json_serializable](https://pub.dev/packages/json_serializable) - JSON code generation
- [riverpod_generator](https://pub.dev/packages/riverpod_generator) - Riverpod code generation
- [flutter_pty](https://pub.dev/packages/flutter_pty) - Pseudo-terminal support

## Getting Started

### Prerequisites

- Flutter 3.41+
- Dart 3.11+

### Install dependencies

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run

```bash
flutter run
```

### Build

```bash
flutter build apk   # Android
flutter build ios   # iOS
```

## License

[MIT](LICENSE)
