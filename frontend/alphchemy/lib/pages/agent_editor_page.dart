import "package:alphchemy/blocs/agent_editor_bloc.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/widgets/agents/agent_system_form.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentEditorPage extends StatelessWidget {
  final Map<String, dynamic>? json;
  final String initialTitle;

  const AgentEditorPage({
    super.key,
    this.json,
    this.initialTitle = "Untitled Agent"
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgentEditorBloc>(
      create: (_) => AgentEditorBloc(initialJson: json),
      child: Scaffold(
        appBar: AgentEditorAppBar(initialTitle: initialTitle),
        body: const AgentSystemForm()
      )
    );
  }
}

class AgentEditorAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String initialTitle;

  const AgentEditorAppBar({super.key, required this.initialTitle});

  @override
  Size get preferredSize {
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  State<AgentEditorAppBar> createState() {
    return _AgentEditorAppBarState();
  }
}

class _AgentEditorAppBarState extends State<AgentEditorAppBar> {
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
        width: 420,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text("Title")
            ),
            Expanded(child: TextField(controller: _titleController))
          ]
        )
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: () => _save(context),
            icon: const Icon(Icons.save),
            label: const Text("Save")
          )
        )
      ]
    );
  }

  void _back(BuildContext context) {
    Navigator.of(context).pop<EditorResult?>(null);
  }

  void _save(BuildContext context) {
    final bloc = context.read<AgentEditorBloc>();
    final title = _titleController.text;
    final json = bloc.exportToJson();
    final result = (title: title, data: json);
    Navigator.of(context).pop<EditorResult?>(result);
  }
}
