import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

typedef EditorResult = ({String title, Map<String, dynamic> data});

class EditorPage extends StatelessWidget {
  final Map<String, dynamic>? json;
  final String initialTitle;
  
  const EditorPage({
    super.key,
    this.json,
    this.initialTitle = "Untitled Experiment"
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      create: (_) => EditorBloc(initialJson: json),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              EditorHeader(initialTitle: initialTitle),
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
  final String initialTitle;

  const EditorHeader({
    super.key,
    required this.initialTitle
  });

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
    _titleController = TextEditingController(text: widget.initialTitle);
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
            onPressed: () => _back(context)
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 300,
            child: TextField(
              style: Theme.of(context).textTheme.displayLarge,
              controller: _titleController
            )
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _queue(context),
            icon: const InvertedIcon(Icons.playlist_add_check),
            label: const InvertedText("Queue")
          )
        ]
      )
    );
  }

  void _back(BuildContext context) {
    Navigator.of(context).pop<EditorResult?>(null);
  }

  void _queue(BuildContext context) {
    final bloc = context.read<EditorBloc>();
    final title = _titleController.text;
    final json = bloc.exportToJson();
    final result = (title: title, data: json);
    Navigator.of(context).pop<EditorResult?>(result);
  }
}
