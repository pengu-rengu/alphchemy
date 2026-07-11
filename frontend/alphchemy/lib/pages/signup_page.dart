import "package:alphchemy/blocs/auth/auth_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart" show SupabaseClient;

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(client: context.read<SupabaseClient>()),
      child: const FScaffold(child: SignUpForm())
    );
  }
}

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final event = SignUpSubmitted(email: emailController.text, password: passwordController.text, confirmPassword: confirmController.text);
    context.read<AuthBloc>().add(event);
  }

  Future<void> _showConfirmation(BuildContext context, String message) async {
    await showDialogUtil<void>(
      context: context,
      title: "Confirm your email",
      content: NormalText(message),
      actions: (innerContext) => [FButton(
        onPress: () => Navigator.pop(innerContext),
        child: const InvertedText("OK")
      )]
    );
    if (context.mounted) context.go("/signin");
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailed) {
          errorDialog(context: context, message: state.message);
        } else if (state is AuthInfo) {
          _showConfirmation(context, state.message);
        }
      },
      child: Center(child: SizedBox(
        width: 360.0,
        child: PaddedCard(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeText("Create an account"),
            const SizedBox(height: 20.0),
            FTextField(
              control: FTextFieldControl.managed(controller: emailController),
              label: const NormalText("Email"),
              keyboardType: TextInputType.emailAddress,
              style: textFieldStyle(context)
            ),
            const SizedBox(height: 10.0),
            FTextField.password(
              control: FTextFieldControl.managed(controller: passwordController),
              label: const NormalText("Password"),
              style: textFieldStyle(context)
            ),
            const SizedBox(height: 10.0),
            FTextField.password(
              control: FTextFieldControl.managed(controller: confirmController),
              label: const NormalText("Confirm password"),
              style: textFieldStyle(context),
              onSubmit: (_) => _submit(context)
            ),
            const SizedBox(height: 20.0),
            AuthSubmitButton(onPress: () => _submit(context), child: const InvertedText("Sign up")),
            const SizedBox(height: 10.0),
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () => context.go("/signin"),
              child: const NormalText("Back to sign in")
            )
          ]
        ))
      ))
    );
  }
}
