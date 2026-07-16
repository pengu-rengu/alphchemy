import "package:alphchemy_app/blocs/auth/auth_bloc.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:json_editor_flutter/json_editor_flutter.dart";

class JsonView extends StatelessWidget {
  final String json;
  final double height;

  const JsonView({super.key, required this.json, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: JsonEditor(
          key: ValueKey<String>(json),
          json: json,
          onChanged: (_) {},
          themeColor: context.theme.colors.border,
          enableMoreOptions: false,
          enableKeyEdit: false,
          enableValueEdit: false
        )
      )
    );
  }
}

FTextFieldStyleDelta textFieldStyle(BuildContext context, {bool mono = false}) {
  final base = context.theme.typography.xs;
  final family = mono ? "RobotoMono" : null;
  final delta = TextStyleDelta.delta(fontSize: base.fontSize, height: base.height, fontFamily: family);
  final operation = FVariantOperation<FTextFieldVariantConstraint, FTextFieldVariant, TextStyle, TextStyleDelta>.all(delta);
  final content = FVariantsDelta.delta([operation]);
  return FTextFieldStyleDelta.delta(contentTextStyle: content);
}

class PaddedCard extends StatelessWidget {
  final Widget child;

  const PaddedCard({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return FCard.raw(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: child
      )
    );
  }
}

class NormalText extends StatelessWidget {
  final String text;
  final int? maxLines;
  final bool mono;

  const NormalText(this.text, {super.key, this.maxLines, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final base = context.theme.typography.xs;
    final style = mono ? base.copyWith(fontFamily: "RobotoMono") : base;
    return Text(text, style: style, maxLines: maxLines);
  }
}

class BoldText extends StatelessWidget {
  final String text;
  final int? maxLines;
  final bool mono;

  const BoldText(this.text, {super.key, this.maxLines, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final base = context.theme.typography.xs.copyWith(fontWeight: FontWeight.bold);
    final style = mono ? base.copyWith(fontFamily: "RobotoMono") : base;
    return Text(text, style: style, maxLines: maxLines);
  }
}

class CenterText extends StatelessWidget {
  final String text;
  final bool expanded;

  const CenterText(this.text, {super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final inner = Center(child: NormalText(text));
    return expanded ? Expanded(child: inner) : inner;
  }
}

class LargeText extends StatelessWidget {
  final String text;

  const LargeText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: context.theme.typography.lg);
  }
}

class InvertedText extends StatelessWidget {
  final String text;

  const InvertedText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.xs.copyWith(color: context.theme.colors.primaryForeground);
    return Text(text, style: style);
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Expanded(child: Center(child: FCircularProgress()));
  }
}

class NormalIcon extends StatelessWidget {
  final IconData icon;
  final bool small;

  const NormalIcon(this.icon, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: context.theme.colors.foreground, size: small ? 10.0 : 20.0);
  }
}

class InvertedIcon extends StatelessWidget {
  final IconData icon;

  const InvertedIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: context.theme.colors.primaryForeground);
  }
}

class ListCell extends StatelessWidget {
  final dynamic value;
  final int flex;
  final bool alignLeft;

  const ListCell({super.key, required this.value, required this.flex, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    final text = value == null ? "-" : value.toString();

    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
        child: NormalText(text)
      )
    );
  }
}

class StyledTextField extends StatelessWidget {
  final TextEditingController? controller;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final bool mono;
  final ValueChanged<String>? onSubmitted;

  const StyledTextField({super.key, this.controller, this.autofocus = false, this.minLines, this.maxLines = 1, this.mono = false, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return FTextField(
      control: FTextFieldControl.managed(controller: controller),
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      onSubmit: onSubmitted,
      style: textFieldStyle(context, mono: mono)
    );
  }
}

class TitleTextField extends StatelessWidget {
  final TextEditingController? controller;

  const TitleTextField({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500.0,
      child: FTextField(
        control: FTextFieldControl.managed(controller: controller)
      )
    );
  }
}

class Header extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;
  final String? errorMessage;

  const Header({super.key, required this.left, required this.right, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
          child: Row(children: [
            ...left,
            const Spacer(),
            ...right
          ])
        ),
        if (errorMessage != null)
          PaddedCard(child: Row(children: [
            const SizedBox(width: 10.0),
            const NormalIcon(Icons.error_outline),
            const SizedBox(width: 10.0),
            NormalText(errorMessage!)
          ]))
      ]
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPress;
  final FButtonVariant variant;
  final MainAxisSize mainAxisSize;

  const AuthSubmitButton({super.key, required this.child, required this.onPress, this.variant = FButtonVariant.primary, this.mainAxisSize = MainAxisSize.max});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final submitting = state is AuthSubmitting;
        return FButton(
          variant: variant,
          mainAxisSize: mainAxisSize,
          onPress: submitting ? null : onPress,
          child: submitting ? const FCircularProgress() : child
        );
      }
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
        const NormalText("unsaved"),
        const SizedBox(width: 10.0)
      ]
    );
  }
}
