import "package:alphchemy/blocs/auth/auth_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/update_password_form.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart" show SupabaseClient;

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(client: context.read<SupabaseClient>()),
      child: const FScaffold(child: ResetPasswordArea())
    );
  }
}

class ResetPasswordArea extends StatelessWidget {
  const ResetPasswordArea({super.key});

  Future<void> _showConfirmation(BuildContext context, String message) async {
    await showDialogUtil<void>(
      context: context,
      title: "Success",
      content: NormalText(message),
      actions: (innerContext) => [FButton(
        onPress: () => Navigator.pop(innerContext),
        child: const InvertedText("OK")
      )]
    );
    if (context.mounted) context.go("/experiments");
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
      child: const Center(child: SizedBox(
        width: 360.0,
        child: ChangePasswordCard(title: "Reset password", stretchButton: true)
      ))
    );
  }
}
