import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
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
        appBar: EditorAppBar(initialTitle: initialTitle),
        body: const ExperimentEditor()
      )
    );
  }
}

class EditorAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String initialTitle;

  const EditorAppBar({
    super.key,
    required this.initialTitle
  });

  @override
  Size get preferredSize {
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  State<EditorAppBar> createState() {
    return _EditorAppBarState();
  }
}

class _EditorAppBarState extends State<EditorAppBar> {
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
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: "Back",
        onPressed: () => _back(context)
      ),
      title: SizedBox(
        width: 360,
        child: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: "Title"
          )
        )
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: () => _queue(context),
            icon: const Icon(Icons.playlist_add_check),
            label: const Text("Queue")
          )
        )
      ]
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
