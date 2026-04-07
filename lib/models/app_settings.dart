import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'terminal_themes.dart';

/// Where session tabs are rendered in the terminal screen.
enum TabPosition { top, left }

/// Theme mode preference.
enum AppThemeMode { system, light, dark }

/// Selectable accent (seed) colors.
enum AppAccentColor {
  teal,
  blue,
  indigo,
  purple,
  pink,
  red,
  orange,
  green;

  Color get color => switch (this) {
        AppAccentColor.teal => Colors.teal,
        AppAccentColor.blue => Colors.blue,
        AppAccentColor.indigo => Colors.indigo,
        AppAccentColor.purple => Colors.purple,
        AppAccentColor.pink => Colors.pink,
        AppAccentColor.red => Colors.red,
        AppAccentColor.orange => Colors.orange,
        AppAccentColor.green => Colors.green,
      };
}

const double terminalFontSizeMin = 8.0;
const double terminalFontSizeMax = 28.0;
const double terminalFontSizeDefault = 14.0;

class AppSettings {
  final TabPosition tabPosition;
  final AppThemeMode appThemeMode;
  final AppAccentColor accentColor;
  final TerminalColorScheme terminalColorScheme;
  final double terminalFontSize;

  const AppSettings({
    this.tabPosition = TabPosition.top,
    this.appThemeMode = AppThemeMode.system,
    this.accentColor = AppAccentColor.teal,
    this.terminalColorScheme = TerminalColorScheme.vscodeDefault,
    this.terminalFontSize = terminalFontSizeDefault,
  });

  AppSettings copyWith({
    TabPosition? tabPosition,
    AppThemeMode? appThemeMode,
    AppAccentColor? accentColor,
    TerminalColorScheme? terminalColorScheme,
    double? terminalFontSize,
  }) {
    return AppSettings(
      tabPosition: tabPosition ?? this.tabPosition,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      accentColor: accentColor ?? this.accentColor,
      terminalColorScheme: terminalColorScheme ?? this.terminalColorScheme,
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'tabPosition': tabPosition.name,
        'appThemeMode': appThemeMode.name,
        'accentColor': accentColor.name,
        'terminalColorScheme': terminalColorScheme.name,
        'terminalFontSize': terminalFontSize,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      tabPosition: TabPosition.values.firstWhere(
        (e) => e.name == json['tabPosition'],
        orElse: () => TabPosition.top,
      ),
      appThemeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == json['appThemeMode'],
        orElse: () => AppThemeMode.system,
      ),
      accentColor: AppAccentColor.values.firstWhere(
        (e) => e.name == json['accentColor'],
        orElse: () => AppAccentColor.teal,
      ),
      terminalColorScheme: TerminalColorScheme.values.firstWhere(
        (e) => e.name == json['terminalColorScheme'],
        orElse: () => TerminalColorScheme.vscodeDefault,
      ),
      terminalFontSize: (json['terminalFontSize'] as num?)?.toDouble()
          ?? terminalFontSizeDefault,
    );
  }

  static Future<AppSettings> load(String storagePath) async {
    final file = File('$storagePath/settings.json');
    if (!await file.exists()) return const AppSettings();
    try {
      return AppSettings.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(String storagePath) async {
    final file = File('$storagePath/settings.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(toJson()));
  }
}
