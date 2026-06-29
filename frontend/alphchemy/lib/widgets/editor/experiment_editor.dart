import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/main.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter/services.dart";

class HighlightStyles {
  final TextStyle base;
  final TextStyle key;
  final TextStyle comment;
  final TextStyle punctuation;
  final TextStyle literal;
  final TextStyle nullValue;

  const HighlightStyles({required this.base, required this.key, required this.comment, required this.punctuation, required this.literal, required this.nullValue});

  factory HighlightStyles.of(BuildContext context, TextStyle base) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return HighlightStyles(
      base: base,
      key: base.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
      comment: base.copyWith(color: colors.fgColor2, fontStyle: FontStyle.italic),
      punctuation: base.copyWith(color: colors.fgColor2),
      literal: base.copyWith(color: scheme.tertiary),
      nullValue: base.copyWith(color: colors.fgColor2, fontStyle: FontStyle.italic)
    );
  }
}

class ExperimentEditingController extends TextEditingController {
  ExperimentEditingController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    final styles = HighlightStyles.of(context, base);
    final lines = text.split("\n");
    final spans = <InlineSpan>[];

    for (var i = 0; i < lines.length; i++) {
      _appendLine(spans, lines[i], styles);
      final isLast = i == lines.length - 1;
      if (!isLast) {
        spans.add(TextSpan(text: "\n", style: base));
      }
    }

    return TextSpan(style: base, children: spans);
  }

  void _appendLine(List<InlineSpan> spans, String line, HighlightStyles styles) {
    final trimmed = line.trimLeft();
    final indentLength = line.length - trimmed.length;
    final indent = line.substring(0, indentLength);

    if (trimmed.isEmpty) {
      spans.add(TextSpan(text: line, style: styles.base));
      return;
    }

    if (trimmed.startsWith("#")) {
      spans.add(TextSpan(text: line, style: styles.comment));
      return;
    }

    spans.add(TextSpan(text: indent, style: styles.base));

    final colonIdx = trimmed.indexOf(":");
    if (colonIdx == -1) {
      spans.add(TextSpan(text: trimmed, style: styles.base));
      return;
    }

    final key = trimmed.substring(0, colonIdx);
    final value = trimmed.substring(colonIdx + 1);
    spans.add(TextSpan(text: key, style: styles.key));
    spans.add(TextSpan(text: ":", style: styles.punctuation));

    if (value.isNotEmpty) {
      final span = _valueSpan(value, styles);
      spans.add(span);
    }
  }

  TextSpan _valueSpan(String text, HighlightStyles styles) {
    final trimmed = text.trim();
    if (trimmed == "null") {
      return TextSpan(text: text, style: styles.nullValue);
    }

    final isNumber = double.tryParse(trimmed) != null;
    final isKeyword = trimmed == "true" || trimmed == "false";
    final style = isNumber || isKeyword ? styles.literal : styles.base;
    return TextSpan(text: text, style: style);
  }
}

class ExperimentIndentFormatter extends TextInputFormatter {
  static const indentUnit = "  ";

  const ExperimentIndentFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final selection = newValue.selection;
    final cursor = selection.baseOffset;

    if (!_isNewlineInsert(oldValue, newValue, cursor)) {
      return newValue;
    }

    final oldCursor = oldValue.selection.baseOffset;
    final previousLine = _lineBeforeCursor(oldValue.text, oldCursor);
    final indent = _nextIndent(previousLine);
    final text = newValue.text.replaceRange(cursor, cursor, indent);
    final offset = cursor + indent.length;
    final newSelection = TextSelection.collapsed(offset: offset);
    return newValue.copyWith(text: text, selection: newSelection, composing: TextRange.empty);
  }

  bool _isNewlineInsert(TextEditingValue oldValue, TextEditingValue newValue, int cursor) {
    if (!oldValue.selection.isCollapsed) {
      return false;
    }
    if (!newValue.selection.isCollapsed) {
      return false;
    }
    if (cursor <= 0) {
      return false;
    }
    if (newValue.text[cursor - 1] != "\n") {
      return false;
    }

    final lengthDiff = newValue.text.length - oldValue.text.length;
    return lengthDiff == 1;
  }

  String _lineBeforeCursor(String text, int cursor) {
    if (cursor <= 0) {
      return "";
    }

    final beforeCursor = text.substring(0, cursor);
    final lineStart = beforeCursor.lastIndexOf("\n") + 1;
    return beforeCursor.substring(lineStart);
  }

  String _nextIndent(String line) {
    final trimmedLeft = line.trimLeft();
    final indentLength = line.length - trimmedLeft.length;
    final indent = line.substring(0, indentLength);

    if (_opensChildBlock(line)) {
      return "$indent$indentUnit";
    }

    return indent;
  }

  bool _opensChildBlock(String line) {
    final trimmedLeft = line.trimLeft();
    if (trimmedLeft.startsWith("#")) {
      return false;
    }

    final trimmedRight = line.trimRight();
    final colonIdx = trimmedRight.indexOf(":");
    if (colonIdx == -1) {
      return false;
    }

    final key = trimmedRight.substring(0, colonIdx).trim();
    final value = trimmedRight.substring(colonIdx + 1).trim();
    return key.isNotEmpty && value.isEmpty;
  }
}

class ExperimentEditor extends StatefulWidget {
  final String source;
  final bool readOnly;

  const ExperimentEditor({super.key}) : source = "", readOnly = false;

  const ExperimentEditor.readOnly({super.key, required this.source}) : readOnly = true;

  @override
  State<ExperimentEditor> createState() => _ExperimentEditorState();
}

class _ExperimentEditorState extends State<ExperimentEditor> {
  late final ExperimentEditingController _controller;

  @override
  void initState() {
    super.initState();
    final source = widget.readOnly ? widget.source : context.read<EditorBloc>().state.source;
    _controller = ExperimentEditingController(text: source);
  }

  @override
  void didUpdateWidget(ExperimentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.source != widget.source;
    if (widget.readOnly && changed) {
      _controller.text = widget.source;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.displayMedium!;
    final monospace = base.copyWith(fontFamily: "RobotoMono");

    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      expands: !widget.readOnly,
      maxLines: null,
      minLines: null,
      scrollPhysics: widget.readOnly ? const NeverScrollableScrollPhysics() : null,
      style: monospace,
      inputFormatters: widget.readOnly ? null : const [ExperimentIndentFormatter()],
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(10.0),
        hintText: "Enter experiment source"
      ),
      onChanged: widget.readOnly ? null : (String value) {
        final event = UpdateExperimentSource(text: value);
        context.read<EditorBloc>().add(event);
      }
    );
  }

}
