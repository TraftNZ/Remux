# Remux - SSH Terminal App

## Project Overview
Flutter SSH terminal app (Android + iOS) for managing remote compute sessions. Inspired by JuiceSSH.

## Tech Stack
- **Flutter** 3.41+ / Dart 3.11+
- **dartssh2** - SSH client (pure Dart)
- **xterm** - Terminal emulator widget
- **flutter_riverpod** + riverpod_generator - State management
- **go_router** - Navigation
- **path_provider** - File system paths
- **flutter_secure_storage** - Encrypted credential storage
- **json_serializable** - JSON serialization codegen

## Architecture
- **Models** (`lib/models/`) - Immutable data classes with JSON serialization
- **Services** (`lib/services/`) - SSH, storage, key management
- **Providers** (`lib/providers/`) - Riverpod state management
- **Screens** (`lib/screens/`) - Full page views
- **Widgets** (`lib/widgets/`) - Reusable UI components

## Data Storage
- JSON files in app documents directory via `path_provider`
- Sensitive data (passwords, private keys) in `flutter_secure_storage`
- Entities: Connection, Identity, Snippet (decoupled like JuiceSSH)

## Key Patterns
- Identities are separate from Connections (change password once, updates everywhere)
- Connections can specify a tmux session name for auto-attach
- Snippets are custom commands executable in any active terminal session
- Multiple concurrent SSH sessions with tab switching

## Commands
```bash
flutter pub get          # Install dependencies
flutter pub run build_runner build --delete-conflicting-outputs  # Generate code
flutter analyze          # Static analysis
flutter test             # Run tests
flutter build apk        # Build Android
flutter build ios        # Build iOS
```

## Code Style
- Strict typing, no `dynamic` unless unavoidable
- Riverpod with code generation (`@riverpod` annotations)
- go_router for declarative routing
- LF line endings only

## Claude Teams

### flutter-engineer
- **Role**: Core feature implementation - SSH service, data layer, providers, screen logic
- **Agent type**: flutter-engineer
- **Model**: opus

### ui-designer
- **Role**: UI/UX design and implementation - layouts, themes, animations, custom widgets
- **Agent type**: flutter-engineer
- **Model**: opus

### code-reviewer
- **Role**: Code quality review - architecture, patterns, security, performance
- **Agent type**: code-reviewer
- **Model**: opus

### tester
- **Role**: Write and run tests - unit tests for models/services/providers, widget tests
- **Agent type**: flutter-engineer
- **Model**: opus
