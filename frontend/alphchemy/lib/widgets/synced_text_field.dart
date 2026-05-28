import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";

class SyncedTextField extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;

  const SyncedTextField({super.key, required this.text, required this.onChanged, this.decoration, this.maxLines = 1, this.minLines});

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus || oldWidget.text == widget.text) {
      return;
    }

    _syncControllerText(widget.text);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) return;

    _syncControllerText(widget.text);
  }

  void _syncControllerText(String text) {
    if (_controller.text == text) return;

    final selection = TextSelection.collapsed(offset: text.length);
    _controller.value = TextEditingValue(
      text: text,
      selection: selection
    );
  }

  @override
  Widget build(BuildContext context) {
    return StyledTextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      onChanged: widget.onChanged
    );
  }
}
