import "package:alphchemy/blocs/agent_editor_bloc.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/widgets/agents/agent_schema_editor.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

typedef AgentSchemaEditorResult = ({String title, AgentSystemSchema schema});

class AgentEditorPage extends StatelessWidget {
  final AgentSystemSchema? schema;
  final String title;

  const AgentEditorPage({super.key, this.schema, this.title = "Untitled"});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AgentEditorBloc>(
      create: (_) => AgentEditorBloc(schema: schema),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AgentEditorHeader(title: title),
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
  final String title;

  const AgentEditorHeader({super.key, required this.title});

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
            tooltip: "Back",
            onPressed: () {
              Navigator.of(context).pop<AgentSchemaEditorResult?>(null);
            }
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 400,
            child: TextField(controller: _titleController)
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop<AgentSchemaEditorResult?>((
                title: _titleController.text,
                schema: context.read<AgentEditorBloc>().state
              ));
            },
            icon: const InvertedIcon(Icons.save),
            label: const InvertedText("Save")
          )
        ]
      )
    );
  }
}
