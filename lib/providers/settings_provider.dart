import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/terminal_themes.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  late String _storagePath;

  @override
  Future<AppSettings> build() async {
    final dir = await getApplicationSupportDirectory();
    _storagePath = dir.path;
    return AppSettings.load(_storagePath);
  }

  Future<void> save(AppSettings settings) async {
    await settings.save(_storagePath);
    state = AsyncData(settings);
  }

  Future<void> setTabPosition(TabPosition position) async {
    final current = state.valueOrNull ?? const AppSettings();
    await save(current.copyWith(tabPosition: position));
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final current = state.valueOrNull ?? const AppSettings();
    await save(current.copyWith(appThemeMode: mode));
  }

  Future<void> setAccentColor(AppAccentColor color) async {
    final current = state.valueOrNull ?? const AppSettings();
    await save(current.copyWith(accentColor: color));
  }

  Future<void> setTerminalColorScheme(TerminalColorScheme scheme) async {
    final current = state.valueOrNull ?? const AppSettings();
    await save(current.copyWith(terminalColorScheme: scheme));
  }
}
