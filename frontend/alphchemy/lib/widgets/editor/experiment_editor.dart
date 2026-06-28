import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/main.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class HighlightStyles {
  final TextStyle base;
  final TextStyle key;
  final TextStyle comment;
  final TextStyle punctuation;
  final TextStyle literal;

  const HighlightStyles({required this.base, required this.key, required this.comment, required this.punctuation, required this.literal});

  factory HighlightStyles.of(BuildContext context, TextStyle base) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return HighlightStyles(
      base: base,
      key: base.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
      comment: base.copyWith(color: colors.fgColor2, fontStyle: FontStyle.italic),
      punctuation: base.copyWith(color: colors.fgColor2),
      literal: base.copyWith(color: scheme.tertiary)
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

    var content = trimmed;
    if (content.startsWith("- ")) {
      spans.add(TextSpan(text: "- ", style: styles.punctuation));
      content = content.substring(2);
    }

    final colonIdx = content.indexOf(":");
    if (colonIdx == -1) {
      final span = _valueSpan(content, styles);
      spans.add(span);
      return;
    }

    final key = content.substring(0, colonIdx);
    final value = content.substring(colonIdx + 1);
    spans.add(TextSpan(text: key, style: styles.key));
    spans.add(TextSpan(text: ":", style: styles.punctuation));

    if (value.isNotEmpty) {
      final span = _valueSpan(value, styles);
      spans.add(span);
    }
  }

  TextSpan _valueSpan(String text, HighlightStyles styles) {
    final trimmed = text.trim();
    final isNumber = double.tryParse(trimmed) != null;
    final isKeyword = trimmed == "true" || trimmed == "false" || trimmed == "null";
    final style = isNumber || isKeyword ? styles.literal : styles.base;
    return TextSpan(text: text, style: style);
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
    final source = _initialSource();
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
      expands: true,
      maxLines: null,
      minLines: null,
      style: monospace,
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

  String _initialSource() {
    if (widget.readOnly) {
      return widget.source;
    }

    final bloc = context.read<EditorBloc>();
    return bloc.state.source;
  }
}
