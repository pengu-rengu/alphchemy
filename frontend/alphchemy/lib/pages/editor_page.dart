import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

typedef ExperimentEditorResult = ({String title, String source});

class EditorPage extends StatelessWidget {
  final String? source;
  final String title;

  const EditorPage({super.key, this.source, this.title = "Untitled"});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      create: (_) => EditorBloc(source: source),
      child: Scaffold(
        body: SafeArea(
          child: EditorArea(title: title)
        )
      )
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
