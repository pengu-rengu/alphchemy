import "package:alphchemy_app/widgets/editor/experiment_editor.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("indent formatter copies previous line indent", () {
    const formatter = ExperimentIndentFormatter();
    const oldText = "  null";
    const newText = "  null\n";
    final oldValue = TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length)
    );
    final newValue = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length)
    );

    final result = formatter.formatEditUpdate(oldValue, newValue);

    expect(result.text, "  null\n  ");
    expect(result.selection.baseOffset, result.text.length);
  });

  test("indent formatter adds child indent after parent key", () {
    const formatter = ExperimentIndentFormatter();
    const oldText = "strategy:";
    const newText = "strategy:\n";
    final oldValue = TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length)
    );
    final newValue = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length)
    );

    final result = formatter.formatEditUpdate(oldValue, newValue);

    expect(result.text, "strategy:\n  ");
    expect(result.selection.baseOffset, result.text.length);
  });

  test("indent formatter keeps inline keys at previous indent", () {
    const formatter = ExperimentIndentFormatter();
    const oldText = "  type: logic";
    const newText = "  type: logic\n";
    final oldValue = TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length)
    );
    final newValue = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length)
    );

    final result = formatter.formatEditUpdate(oldValue, newValue);

    expect(result.text, "  type: logic\n  ");
    expect(result.selection.baseOffset, result.text.length);
  });
}
