import "package:alphchemy_app/blocs/experiments/editor_bloc.dart";
import "package:alphchemy_app/blocs/experiments/validation_bloc.dart";
import "package:alphchemy_app/widgets/editor/experiment_editor.dart";
import "package:alphchemy_app/widgets/dialog_utils.dart";
import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
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
      child: ValidationListener(child: FScaffold(
        childPad: false,
        child: EditorArea(title: title)
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
        const FDivider(),
        // ignore: prefer_const_constructors
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          // ignore: prefer_const_constructors
          child: ExperimentEditor()
        )),
        const SizedBox(height: 10.0)
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
            FButton.icon(
              onPress: () => Navigator.pop<ExperimentEditorResult?>(context),
              variant: FButtonVariant.ghost,
              child: const NormalIcon(Icons.arrow_back)
            ),
            const SizedBox(width: 10.0),
            TitleTextField(
              controller: _titleController
            )
          ],
          right: [
            const ValidateButton(),
            const SizedBox(width: 10.0),
            FButton(
              onPress: () {
                final source = context.read<EditorBloc>().state.source;
                Navigator.pop<ExperimentEditorResult?>(context, (
                  title: _titleController.text,
                  source: source
                ));
              },
              prefix: const InvertedIcon(Icons.playlist_add_check),
              child: const InvertedText("Queue")
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
          return FButton(
            onPress: null,
            prefix: const SizedBox(
              width: 16.0,
              height: 16.0,
              child: FCircularProgress()
            ),
            child: const InvertedText("Validating")
          );
        }

        return FButton(
          onPress: () {
            final source = context.read<EditorBloc>().state.source;
            final event = ValidateExperiment(source: source);
            context.read<ValidationBloc>().add(event);
          },
          prefix: const InvertedIcon(Icons.check_circle_outline),
          child: const InvertedText("Validate")
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
            actions: (innerContext) => [FButton(
              onPress: () => Navigator.pop(innerContext),
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
