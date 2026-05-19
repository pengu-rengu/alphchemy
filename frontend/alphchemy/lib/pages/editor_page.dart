import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

typedef ExperimentEditorResult = ({String title, Experiment experiment});

class EditorPage extends StatelessWidget {
  final Experiment? experiment;
  final String title;
  
  const EditorPage({super.key, this.experiment, this.title = "Untitled"});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      create: (_) => EditorBloc(experiment: experiment),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              EditorHeader(title: title),
              const Divider(height: 1),
              const Expanded(child: ExperimentEditor())
            ]
          )
        )
      )
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const NormalIcon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop<ExperimentEditorResult?>(null);
            }
          ),
          const SizedBox(width: 10.0),
          SizedBox(
            width: 300.0,
            child: TextField(
              style: Theme.of(context).textTheme.displayLarge,
              controller: _titleController
            )
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop<ExperimentEditorResult?>((
                title: _titleController.text,
                experiment: context.read<EditorBloc>().state.experiment
              ));
            },
            icon: const InvertedIcon(Icons.playlist_add_check),
            label: const InvertedText("Queue")
          )
        ]
      )
    );
  }
}
