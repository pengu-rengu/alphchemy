import "package:flutter/material.dart";

class SyncedTextField extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final TextStyle? style;
  final InputDecoration? decoration;

  const SyncedTextField({super.key, required this.text, required this.onChanged, this.style, this.decoration});

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    if (_controller.text == widget.text) return;

    final selection = TextSelection.collapsed(offset: widget.text.length);
    _controller.value = TextEditingValue(
      text: widget.text,
      selection: selection
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ?? const InputDecoration();
    return TextField(
      controller: _controller,
      style: widget.style,
      decoration: decoration,
      onChanged: widget.onChanged
    );
  }
}
