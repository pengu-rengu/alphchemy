import "package:alphchemy/blocs/agent_editor_bloc.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/widgets/agents/agent_schema_editor.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
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
        body: SafeArea(
          child: Column(
            children: [
              AgentEditorHeader(initialTitle: initialTitle),
              const Divider(height: 1),
              const Expanded(child: AgentSchemaEditor())
            ]
          )
        )
      )
    );
  }
}

class AgentEditorHeader extends StatefulWidget {
  final String initialTitle;

  const AgentEditorHeader({super.key, required this.initialTitle});

  @override
  State<AgentEditorHeader> createState() {
    return _AgentEditorHeaderState();
  }
}

class _AgentEditorHeaderState extends State<AgentEditorHeader> {
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
            tooltip: "Back",
            onPressed: () => _back(context)
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 400,
            child: TextField(controller: _titleController)
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _save(context),
            icon: const InvertedIcon(Icons.save),
            label: const InvertedText("Save")
          )
        ]
      )
    );
  }

  void _back(BuildContext context) {
    Navigator.of(context).pop<EditorResult?>(null);
  }

  void _save(BuildContext context) {
    final bloc = context.read<AgentEditorBloc>();
    final title = _titleController.text;
    final json = bloc.state.toJson();
    final result = (title: title, data: json);
    Navigator.of(context).pop<EditorResult?>(result);
  }
}
