import "package:alphchemy_app/blocs/auth/auth_bloc.dart";
import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";

class ChangePasswordCard extends StatefulWidget {
  final String title;
  final bool stretchButton;

  const ChangePasswordCard({super.key, this.title = "Change password", this.stretchButton = false});

  @override
  State<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<ChangePasswordCard> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final event = ChangePasswordSubmitted(password: passwordController.text, confirmPassword: confirmController.text);
    context.read<AuthBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    final button = AuthSubmitButton(
      mainAxisSize: widget.stretchButton ? MainAxisSize.max : MainAxisSize.min,
      onPress: () => _submit(context),
      child: const InvertedText("Update password")
    );
    return PaddedCard(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoldText(widget.title),
        const SizedBox(height: 10.0),
        FTextField.password(
          control: FTextFieldControl.managed(controller: passwordController),
          label: const NormalText("New password"),
          style: textFieldStyle(context)
        ),
        const SizedBox(height: 10.0),
        FTextField.password(
          control: FTextFieldControl.managed(controller: confirmController),
          label: const NormalText("Confirm password"),
          style: textFieldStyle(context),
          onSubmit: (_) => _submit(context)
        ),
        const SizedBox(height: 10.0),
        if (widget.stretchButton) button else Align(alignment: Alignment.centerLeft, child: button)
      ]
    ));
  }
}
