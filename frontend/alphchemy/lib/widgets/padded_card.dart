import "package:flutter/material.dart";

class PaddedCard extends StatelessWidget {
  final Widget child;

  const PaddedCard({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: child,
      )
    );
  }
}