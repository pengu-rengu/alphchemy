import "package:alphchemy/blocs/auth/auth_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart" show SupabaseClient;

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(client: context.read<SupabaseClient>()),
      child: const FScaffold(child: SignInForm())
    );
  }
}

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final event = SignInSubmitted(email: emailController.text, password: passwordController.text);
    context.read<AuthBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailed) errorDialog(context: context, message: state.message);
      },
      child: Center(child: SizedBox(
        width: 360.0,
        child: PaddedCard(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeText("Sign in"),
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
              style: textFieldStyle(context),
              onSubmit: (_) => _submit(context)
            ),
            const SizedBox(height: 20.0),
            AuthSubmitButton(onPress: () => _submit(context), child: const InvertedText("Sign in")),
            const SizedBox(height: 10.0),
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () => context.go("/signup"),
              child: const NormalText("Create an account")
            )
          ]
        ))
      ))
    );
  }
}
