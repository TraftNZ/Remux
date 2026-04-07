import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/terminal_themes.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final tabPosition = settings?.tabPosition ?? TabPosition.top;
    final themeMode = settings?.appThemeMode ?? AppThemeMode.system;
    final accentColor = settings?.accentColor ?? AppAccentColor.teal;
    final terminalColorScheme =
        settings?.terminalColorScheme ?? TerminalColorScheme.vscodeDefault;
    final fontSize = settings?.terminalFontSize ?? terminalFontSizeDefault;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Terminal'),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Font Size'),
            subtitle: Text('${fontSize.toStringAsFixed(0)} pt'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: fontSize > terminalFontSizeMin
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .setFontSize(fontSize - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: fontSize < terminalFontSizeMax
                      ? () => ref
                          .read(settingsProvider.notifier)
                          .setFontSize(fontSize + 1)
                      : null,
                ),
              ],
            ),
          ),
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.palette),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Mode'),
                      const SizedBox(height: 8),
                      SegmentedButton<AppThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: AppThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) {
                          ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.color_lens),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Accent Color'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppAccentColor.values.map((c) {
                          final isSelected = c == accentColor;
                          return GestureDetector(
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setAccentColor(c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c.color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _SectionHeader('Terminal Color Scheme'),
          ...TerminalColorScheme.values.map((scheme) {
            final isSelected = scheme == terminalColorScheme;
            final t = scheme.theme;
            final swatches = <Color>[
              t.red,
              t.green,
              t.yellow,
              t.blue,
              t.magenta,
              t.cyan,
              t.white,
              t.brightBlack,
            ];
            return InkWell(
              onTap: () => ref
                  .read(settingsProvider.notifier)
                  .setTerminalColorScheme(scheme),
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.background,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : Border.all(
                          color: Colors.white24,
                          width: 1,
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scheme.label,
                            style: TextStyle(
                              color: t.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: swatches
                                .map((c) => Container(
                                      width: 14,
                                      height: 14,
                                      margin:
                                          const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            );
          }),
          const _SectionHeader('Session Tabs'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tab_outlined),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tab Position'),
                      const SizedBox(height: 8),
                      SegmentedButton<TabPosition>(
                        segments: const [
                          ButtonSegment(
                            value: TabPosition.top,
                            label: Text('Top'),
                            icon: Icon(Icons.border_top),
                          ),
                          ButtonSegment(
                            value: TabPosition.left,
                            label: Text('Left'),
                            icon: Icon(Icons.border_left),
                          ),
                        ],
                        selected: {tabPosition},
                        onSelectionChanged: (selection) {
                          ref
                              .read(settingsProvider.notifier)
                              .setTabPosition(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
