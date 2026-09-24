import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remux/widgets/terminal_toolbar.dart';

void main() {
  Future<void> showToolbar(
    WidgetTester tester, {
    required bool vertical,
    required List<String> keys,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: vertical
              ? Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    TerminalToolbar(
                      vertical: true,
                      onKey: keys.add,
                      onSnippets: () {},
                      onCopy: () {},
                      ctrlActive: false,
                      altActive: false,
                      onCtrlToggle: () {},
                      onAltToggle: () {},
                    ),
                  ],
                )
              : Column(
                  children: [
                    const Expanded(child: SizedBox()),
                    TerminalToolbar(
                      onKey: keys.add,
                      onSnippets: () {},
                      onCopy: () {},
                      ctrlActive: false,
                      altActive: false,
                      onCtrlToggle: () {},
                      onAltToggle: () {},
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  testWidgets('horizontal submenu stays above the primary bar and toggles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final keys = <String>[];
    await showToolbar(tester, vertical: false, keys: keys);

    expect(find.text('↑'), findsNothing);
    await tester.ensureVisible(find.text('Nav ▸'));
    await tester.tap(find.text('Nav ▸'));
    await tester.pumpAndSettle();
    expect(find.text('↑'), findsOneWidget);
    await tester.tap(find.text('↑'));
    expect(keys, ['\x1b[A']);
    await tester.tap(find.text('Nav ▾'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Keys ▸'));
    await tester.tap(find.text('Keys ▸'));
    await tester.pumpAndSettle();

    expect(find.text('Enter'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Esc')).dy,
      lessThan(tester.getTopLeft(find.text('Enter')).dy),
    );
    await tester.tap(find.text('Esc'));
    expect(keys, ['\x1b[A', '\x1b']);

    await tester.tap(find.text('Keys ▾'));
    await tester.pumpAndSettle();
    expect(find.text('Esc'), findsNothing);
    expect(find.text('Enter'), findsOneWidget);

    await tester.ensureVisible(find.text('tmux ▸'));
    await tester.tap(find.text('tmux ▸'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('9')).dy,
      greaterThan(tester.getTopLeft(find.text('0')).dy),
    );

    await tester.ensureVisible(find.text('Fn ▸'));
    await tester.tap(find.text('Fn ▸'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);
    expect(find.text('F12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical submenu stays beside primary bar and can switch', (
    tester,
  ) async {
    final keys = <String>[];
    await showToolbar(tester, vertical: true, keys: keys);

    await tester.ensureVisible(find.text('tmux ▸'));
    await tester.tap(find.text('tmux ▸'));
    await tester.pumpAndSettle();

    expect(find.text('Enter'), findsOneWidget);
    expect(find.text('C-b'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('C-b')).dx,
      lessThan(tester.getTopLeft(find.text('Enter')).dx),
    );

    await tester.ensureVisible(find.text('Fn ▸'));
    await tester.tap(find.text('Fn ▸'));
    await tester.pumpAndSettle();
    expect(find.text('C-b'), findsNothing);
    expect(find.text('F1'), findsOneWidget);
    await tester.tap(find.text('F1'));
    expect(keys, ['\x1bOP']);

    await tester.tap(find.text('Fn ▾'));
    await tester.pumpAndSettle();
    expect(find.text('F1'), findsNothing);
  });
}
