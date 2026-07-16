import "package:alphchemy_app/blocs/auth/api_key_bloc.dart";
import "package:alphchemy_app/blocs/auth/auth_bloc.dart";
import "package:alphchemy_app/blocs/theme_bloc.dart";
import "package:alphchemy_app/widgets/dialog_utils.dart";
import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:alphchemy_app/widgets/page_scaffold.dart";
import "package:alphchemy_app/widgets/update_password_form.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:supabase_flutter/supabase_flutter.dart" show SupabaseClient;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) {
            final client = context.read<SupabaseClient>();
            return AuthBloc(client: client);
          }
        ),
        BlocProvider<ApiKeyBloc>(
          create: (_) {
            final client = context.read<SupabaseClient>();
            final bloc = ApiKeyBloc(client: client);
            bloc.add(const LoadApiKey());
            return bloc;
          }
        )
      ],
      child: const PageScaffold(selectedIdx: 3, child: SettingsArea())
    );
  }
}

class SettingsArea extends StatelessWidget {
  const SettingsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
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
          }
        ),
        BlocListener<ApiKeyBloc, ApiKeyState>(
          listener: (context, state) {
            if (state is ApiKeyError) {
              errorDialog(context: context, message: state.message);
            }
          }
        )
      ],
      child: const Column(children: [
        Header(left: [LargeText("Settings")], right: []),
        FDivider(),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Column(children: [
            AppearanceCard(),
            SizedBox(height: 10.0),
            ApiKeyCard(),
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

class ApiKeyCard extends StatelessWidget {
  const ApiKeyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApiKeyBloc, ApiKeyState>(
      builder: (context, state) {
        final loading = state is ApiKeyLoading || state is ApiKeyInitial;
        final apiKey = state is ApiKeyLoaded ? state.apiKey : null;
        final buttonText = apiKey == null ? "Generate API key" : "Regenerate API key";

        return PaddedCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BoldText("MCP API key"),
            const SizedBox(height: 10.0),
            const NormalText("Use this key in the MCP URL. Regenerating it immediately revokes the previous URL."),
            if (apiKey != null) ...[
              const SizedBox(height: 10.0),
              ApiKeyValue(apiKey: apiKey),
              const SizedBox(height: 10.0),
              McpSetupGuide(apiKey: apiKey)
            ],
            const SizedBox(height: 10.0),
            Align(
              alignment: Alignment.centerLeft,
              child: FButton(
                mainAxisSize: MainAxisSize.min,
                onPress: loading ? null : () {
                  final bloc = context.read<ApiKeyBloc>();
                  bloc.add(const GenerateApiKey());
                },
                child: loading ? const FCircularProgress() : InvertedText(buttonText)
              )
            )
          ]
        ));
      }
    );
  }
}

class ApiKeyValue extends StatelessWidget {
  final String apiKey;

  const ApiKeyValue({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: SelectableText(apiKey)),
      const SizedBox(width: 10.0),
      FButton.icon(
        variant: FButtonVariant.ghost,
        onPress: () async {
          final data = ClipboardData(text: apiKey);
          await Clipboard.setData(data);
        },
        child: const NormalIcon(Icons.copy)
      )
    ]);
  }
}

class McpSetupGuide extends StatelessWidget {
  final String apiKey;

  const McpSetupGuide({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final mcpUrl = "http://localhost:8000/mcp/$apiKey";
    final codexCommand = "codex mcp add alphchemy --url $mcpUrl";
    final claudeCommand = "claude mcp add --transport http alphchemy $mcpUrl";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BoldText("Add to Codex"),
        const SizedBox(height: 5.0),
        McpCommand(command: codexCommand),
        const SizedBox(height: 10.0),
        const BoldText("Add to Claude Code"),
        const SizedBox(height: 5.0),
        McpCommand(command: claudeCommand)
      ]
    );
  }
}

class McpCommand extends StatelessWidget {
  final String command;

  const McpCommand({super.key, required this.command});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: SelectableText(command)),
      const SizedBox(width: 10.0),
      FButton.icon(
        variant: FButtonVariant.ghost,
        onPress: () async {
          final data = ClipboardData(text: command);
          await Clipboard.setData(data);
        },
        child: const NormalIcon(Icons.copy)
      )
    ]);
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
