import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('hidden keyboard mode survives terminal changes and can reopen', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      );
    });

    final terminals = [Terminal(), Terminal()];
    final viewKey = GlobalKey<TerminalViewState>();
    var activeIndex = 0;
    var keyboardEnabled = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: TerminalView(
                terminals[activeIndex],
                key: viewKey,
                autofocus: true,
                hardwareKeyboardOnly: !keyboardEnabled,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    update(() => keyboardEnabled = false);
    await tester.pumpAndSettle();
    calls.clear();

    update(() => activeIndex = 1);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('TextInput.show')));

    update(() => keyboardEnabled = true);
    await tester.pumpAndSettle();
    viewKey.currentState!.requestKeyboard();
    await tester.pumpAndSettle();
    expect(calls, contains('TextInput.show'));
  });
}
