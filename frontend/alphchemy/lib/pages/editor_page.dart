import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

typedef EditorResult = ({String title, Map<String, dynamic> data});

class EditorPage extends StatelessWidget {
  final Map<String, dynamic>? json;
  
  const EditorPage({super.key, this.json});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      create: (_) => EditorBloc(),
        child: const Scaffold(
        appBar: EditorAppBar(),
        body: ExperimentEditor()
      )
    );
  }
}

class EditorAppBar extends StatefulWidget implements PreferredSizeWidget {
  const EditorAppBar({super.key});

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
    _titleController = TextEditingController(text: "Untitled Experiment");
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
