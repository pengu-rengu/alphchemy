import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/blocs/experiments/validation_bloc.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

typedef ExperimentEditorResult = ({String title, String source});

class EditorPage extends StatelessWidget {
  final String? source;
  final String title;

  const EditorPage({super.key, this.source, this.title = "Untitled"});

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return MultiBlocProvider(
      providers: [
        BlocProvider<EditorBloc>(create: (_) => EditorBloc(source: source)),
        BlocProvider<ValidationBloc>(create: (_) => ValidationBloc(client: client))
      ],
      child: ValidationListener(child: Scaffold(
        body: SafeArea(
          child: EditorArea(title: title)
        )
      ))
    );
  }
}

class EditorArea extends StatelessWidget {
  final String title;

  const EditorArea({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EditorHeader(title: title),
        const Divider(height: 1),
        // ignore: prefer_const_constructors
        Expanded(child: ExperimentEditor())
      ]
    );
  }
}

class EditorHeader extends StatefulWidget {
  final String title;

  const EditorHeader({super.key, required this.title});

  @override
  State<EditorHeader> createState() {
    return _EditorHeaderState();
  }
}

class _EditorHeaderState extends State<EditorHeader> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      buildWhen: (previous, current) => previous.errorMessage != current.errorMessage,
      builder: (context, state) {
        return Header(
          left: [
            IconButton(
              icon: const NormalIcon(Icons.arrow_back),
              onPressed: () => Navigator.pop<ExperimentEditorResult?>(context)
            ),
            const SizedBox(width: 10.0),
            TitleTextField(
              controller: _titleController
            )
          ],
          right: [
            const ValidateButton(),
            const SizedBox(width: 10.0),
            FilledButton.icon(
              onPressed: () {
                final source = context.read<EditorBloc>().state.source;
                Navigator.pop<ExperimentEditorResult?>(context, (
                  title: _titleController.text,
                  source: source
                ));
              },
              icon: const InvertedIcon(Icons.playlist_add_check),
              label: const InvertedText("Queue")
            )
          ],
          errorMessage: state.errorMessage
        );
      }
    );
  }
}

class ValidateButton extends StatelessWidget {
  const ValidateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ValidationBloc, ValidationState>(
      builder: (context, state) {
        if (state is ValidationWorking) {
          return FilledButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16.0,
              height: 16.0,
              child: CircularProgressIndicator(strokeWidth: 2.0)
            ),
            label: const InvertedText("Validating")
          );
        }

        return FilledButton.icon(
          onPressed: () {
            final source = context.read<EditorBloc>().state.source;
            final event = ValidateExperiment(source: source);
            context.read<ValidationBloc>().add(event);
          },
          icon: const InvertedIcon(Icons.check_circle_outline),
          label: const InvertedText("Validate")
        );
      }
    );
  }
}

class ValidationListener extends StatelessWidget {
  final Widget child;

  const ValidationListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ValidationBloc, ValidationState>(
      listener: (context, state) async {
        if (state is ValidationCompleted) {
          await showDialogUtil<void>(
            context: context,
            title: state.isValid ? "Valid" : "Invalid",
            content: NormalText(state.message),
            actions: (innerContext) => [FilledButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const InvertedText("Close")
            )]
          );
          if (context.mounted) _resetValidation(context);
        } else if (state is ValidationError) {
          await errorDialog(context: context, message: state.message);
          if (context.mounted) _resetValidation(context);
        }
      },
      child: child
    );
  }

  void _resetValidation(BuildContext context) => context.read<ValidationBloc>().add(const ResetValidation());
}
