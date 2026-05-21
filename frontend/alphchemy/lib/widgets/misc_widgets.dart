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

class Header extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;

  const Header({super.key, required this.left, required this.right});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(children: [
        ...left,
        const Spacer(),
        ...right 
      ]),
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

class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.displayMedium;
    final textStyle = style?.copyWith(color: colors.onErrorContainer);

    return Container(
      width: double.infinity,
      color: colors.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Text(message, style: textStyle)
    );
  }
}

class StaleIndicator extends StatelessWidget {
  final bool stale;

  const StaleIndicator({super.key, required this.stale});

  @override
  Widget build(BuildContext context) {
    if (!stale) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.0,
          height: 10.0,
          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)
        ),
        const SizedBox(width: 5.0),
        const NormalText("stale"),
        const SizedBox(width: 10.0)
      ]
    );
  }
}
