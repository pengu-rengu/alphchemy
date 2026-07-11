import "package:alphchemy/blocs/auth/auth_bloc.dart";
import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:supabase_flutter/supabase_flutter.dart" show SupabaseClient;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(client: context.read<SupabaseClient>()),
      child: const PageScaffold(selectedIdx: 3, child: SettingsArea())
    );
  }
}

class SettingsArea extends StatelessWidget {
  const SettingsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailed) {
          errorDialog(context: context, message: state.message);
        } else if (state is AuthInfo) {
          showDialogUtil<void>(
            context: context,
            title: "Success",
            content: NormalText(state.message),
            actions: (innerContext) => [FButton(
              onPress: () => Navigator.pop(innerContext),
              child: const InvertedText("OK")
            )]
          );
        }
      },
      child: const Column(children: [
        Header(left: [LargeText("Settings")], right: []),
        FDivider(),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Column(children: [
            AppearanceCard(),
            SizedBox(height: 10.0),
            ChangePasswordCard(),
            SizedBox(height: 10.0),
            AccountCard()
          ])
        ))
      ])
    );
  }
}

class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaddedCard(child: Row(children: [
      BoldText("Theme"),
      Spacer(),
      ThemeToggleButton()
    ]));
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, mode) {
        final isDark = mode == ThemeMode.dark;
        return FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () => context.read<ThemeBloc>().add(const ToggleTheme()),
          child: NormalIcon(isDark ? Icons.light_mode : Icons.dark_mode)
        );
      }
    );
  }
}

class ChangePasswordCard extends StatefulWidget {
  const ChangePasswordCard({super.key});

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
    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BoldText("Change password"),
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
        Align(
          alignment: Alignment.centerLeft,
          child: AuthSubmitButton(mainAxisSize: MainAxisSize.min, onPress: () => _submit(context), child: const InvertedText("Update password"))
        )
      ]
    ));
  }
}

class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BoldText("Account"),
        const SizedBox(height: 10.0),
        Align(
          alignment: Alignment.centerLeft,
          child: AuthSubmitButton(
            variant: FButtonVariant.destructive,
            mainAxisSize: MainAxisSize.min,
            onPress: () => context.read<AuthBloc>().add(const SignOutRequested()),
            child: const NormalText("Sign out")
          )
        )
      ]
    ));
  }
}
