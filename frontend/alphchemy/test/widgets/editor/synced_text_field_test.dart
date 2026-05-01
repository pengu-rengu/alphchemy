import "package:alphchemy/widgets/editor/synced_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("keeps focused draft when parent text changes", (WidgetTester tester) async {
    final changes = <String>[];

    await _pumpField(tester, "3.0", changes.add);
    await _focusField(tester);
    await _enterFieldText(tester, "3.0,");
    await tester.pump();

    await _pumpField(tester, "0.0", changes.add);

    _expectFieldText(tester, "3.0,");
    _expectChangesContain(changes, "3.0,");
  });

  testWidgets("syncs parent text when unfocused", (WidgetTester tester) async {
    final changes = <String>[];

    await _pumpField(tester, "3.0", changes.add);
    await _pumpField(tester, "0.0", changes.add);

    _expectFieldText(tester, "0.0");
  });

  testWidgets("normalizes focused draft when focus is lost", (WidgetTester tester) async {
    final changes = <String>[];

    await _pumpField(tester, "3.0", changes.add);
    await _focusField(tester);
    await _enterFieldText(tester, "3.0,");
    await tester.pump();

    await _pumpField(tester, "0.0", changes.add);
    _expectFieldText(tester, "3.0,");

    await _tapUnfocusButton(tester);
    await tester.pump();

    _expectFieldText(tester, "0.0");
  });
}

Future<void> _pumpField(
  WidgetTester tester,
  String text,
  ValueChanged<String> onChanged
) async {
  final shell = _FieldShell(text: text, onChanged: onChanged);
  await tester.pumpWidget(shell);
}

Future<void> _focusField(WidgetTester tester) async {
  final fieldFinder = find.byType(TextField);
  await tester.tap(fieldFinder);
}

Future<void> _enterFieldText(WidgetTester tester, String text) async {
  final fieldFinder = find.byType(TextField);
  await tester.enterText(fieldFinder, text);
}

Future<void> _tapUnfocusButton(WidgetTester tester) async {
  const buttonKey = ValueKey<String>("unfocus_button");
  final buttonFinder = find.byKey(buttonKey);
  await tester.tap(buttonFinder);
}

void _expectFieldText(WidgetTester tester, String expectedText) {
  final text = _fieldText(tester);
  expect(text, expectedText);
}

void _expectChangesContain(List<String> changes, String expectedText) {
  final expectedChange = contains(expectedText);
  expect(changes, expectedChange);
}

String _fieldText(WidgetTester tester) {
  final editableFinder = find.byType(EditableText);
  final editableText = tester.widget<EditableText>(editableFinder);
  return editableText.controller.text;
}

class _FieldShell extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const _FieldShell({
    required this.text,
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Material(
        child: Column(
          children: [
            SyncedTextField(
              text: text,
              onChanged: onChanged
            ),
            TextButton(
              key: const ValueKey<String>("unfocus_button"),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: const Text("Unfocus")
            )
          ]
        )
      )
    );
  }
}
