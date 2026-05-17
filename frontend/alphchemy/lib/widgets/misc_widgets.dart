import "package:alphchemy/main.dart";
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

class NormalText extends StatelessWidget {
  final String text;
  final int? maxLines;

  const NormalText(this.text, {super.key, this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.displayMedium, maxLines: maxLines);
  }
}

class BoldText extends StatelessWidget {
  final String text;

  const BoldText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class LargeText extends StatelessWidget {
  final String text;

  const LargeText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.displayLarge);
  }
}

class InvertedText extends StatelessWidget {
  final String text;

  const InvertedText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelMedium);
  }
}

class NormalIcon extends StatelessWidget {
  final IconData icon;

  const NormalIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Theme.of(context).extension<AppColors>()!.fgColor1);
  }
}

class InvertedIcon extends StatelessWidget {
  final IconData icon;

  const InvertedIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Theme.of(context).textTheme.labelMedium?.color);
  }
}
