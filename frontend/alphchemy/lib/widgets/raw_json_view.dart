import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";

class RawJsonView extends StatelessWidget {
  final String jsonText;

  const RawJsonView({super.key, required this.jsonText});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: NormalText(jsonText)
    );
  }
}
