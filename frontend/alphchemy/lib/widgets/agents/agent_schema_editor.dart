import "package:alphchemy/blocs/agent_editor_bloc.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";
import "package:alphchemy/widgets/padded_card.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Text(text)
    );
  }
}

class AgentSchemaEditor extends StatelessWidget {
  const AgentSchemaEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentEditorBloc, AgentSystemSchema>(
      builder: (context, state) {
        // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
        // ignore: prefer_const_constructors
        return SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          // ignore: prefer_const_constructors
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // ignore: prefer_const_literals_to_create_immutables
            children: [
              // ignore: prefer_const_constructors
              AgentSection(title: "Agents", isSubagent: false),
              const SizedBox(height: 10),
              // ignore: prefer_const_constructors
              AgentSection(title: "Subagent pool", isSubagent: true)
            ]
          )
        );
      }
    );
  }
}

class AgentSection extends StatelessWidget {
  final String title;
  final bool isSubagent;

  const AgentSection({super.key, required this.title, required this.isSubagent});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentEditorBloc>().state;
    final agents = isSubagent ? state.subagentPool : state.agents;
    final headerStyle = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: headerStyle)),
            OutlinedButton.icon(
              onPressed: () => _addAgent(context),
              icon: const Icon(Icons.add),
              label: const Text("Add agent")
            )
          ]
        ),
        const SizedBox(height: 12),
        ...(() {
          if (agents.isEmpty) {
            return const [Text("No agents")];
          }
          final widgets = <Widget>[];
          for (var i = 0; i < agents.length; i++) {
            final card = AgentConfigCard(
              agent: agents[i],
              idx: i,
              isSubagent: isSubagent
            );
            widgets.add(card);

            const spacing = SizedBox(height: 10.0);
            widgets.add(spacing);
          }
          return widgets;
        })()
            ]
    );
  }

  void _addAgent(BuildContext context) {
    final event = AddAgent(isSubagent: isSubagent);
    context.read<AgentEditorBloc>().add(event);
  }
}

class AgentConfigCard extends StatelessWidget {
  final AgentConfig agent;
  final int idx;
  final bool isSubagent;

  const AgentConfigCard({super.key, required this.agent, required this.idx, required this.isSubagent});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FieldLabel(text: "ID"),
              Expanded(
                child: SyncedTextField(
                  text: agent.id,
                  onChanged: (value) => _updateField(context, "id", value)
                )
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "Remove agent",
                onPressed: () => _remove(context)
              )
            ]
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const FieldLabel(text: "Max Context Length"),
              Expanded(child: SyncedTextField(
                text: "${agent.maxContextLen}",
                onChanged: (value) => _updateField(context, "maxContextLen", value, intValue: true)
              ))
            ]
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const FieldLabel(text: "# Of Messages to Delete"),
              Expanded(child: SyncedTextField(
                text: "${agent.nDelete}",
                onChanged: (value) => _updateField(context, "nDelete", value, intValue: true)
              ))
            ]
          ),
          const SizedBox(height: 12),
          ModelChipsEditor(
            label: "Chat Models",
            models: agent.chatModels,
            idx: idx,
            isSubagent: isSubagent,
            isSummarize: false
          ),
          const SizedBox(height: 8),
          ModelChipsEditor(
            label: "Summarize Models",
            models: agent.summarizeModels,
            idx: idx,
            isSubagent: isSubagent,
            isSummarize: true
          )
        ]
      )
    );
  }

  void _updateField(BuildContext context, String field, String text, {bool intValue = false}) {
    dynamic value = text;

    if (intValue) {
      value = int.tryParse(text);
      if (value == null) {
        return;
      }
    }

    final event = UpdateAgentField(
      idx: idx,
      isSubagent: isSubagent,
      field: field,
      value: value
    );
    context.read<AgentEditorBloc>().add(event);
  }

  void _remove(BuildContext context) {
    final event = RemoveAgent(idx: idx, isSubagent: isSubagent);
    context.read<AgentEditorBloc>().add(event);
  }
}

class ModelChipsEditor extends StatefulWidget {
  final String label;
  final List<String> models;
  final int idx;
  final bool isSubagent;
  final bool isSummarize;

  const ModelChipsEditor({super.key, required this.label, required this.models, required this.idx, required this.isSubagent, required this.isSummarize});

  @override
  State<ModelChipsEditor> createState() => _ModelChipsEditorState();
}

class _ModelChipsEditorState extends State<ModelChipsEditor> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(text: widget.label),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (() {
                  final widgets = <Widget>[];
                  for (var i = 0; i < widget.models.length; i++) {
                    final chip = InputChip(
                      label: Text(widget.models[i]),
                      onDeleted: () => _remove(i)
                    );
                    widgets.add(chip);
                  }
                  return widgets;
                })()
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(hintText: "Add ${widget.label}"),
                      onSubmitted: (_) => _add()
                    )
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _add
                  )
                ]
              )
            ]
          )
        )
      ]
    );
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }

    final idx = widget.idx;
    late AgentEditorEvent event;
    if (widget.isSummarize) {
      event = AddSummarizeModel(
        idx: idx,
        isSubagent: widget.isSubagent,
        model: value
      );
    } else {
      event = AddChatModel(
        idx: idx,
        isSubagent: widget.isSubagent,
        model: value
      );
    }

    context.read<AgentEditorBloc>().add(event);
    _controller.clear();
  }

  void _remove(int modelIdx) {
    final AgentEditorEvent event;
    final idx = widget.idx;
    if (widget.isSummarize) {
      event = DeleteSummarizeModel(
        idx: idx,
        isSubagent: widget.isSubagent,
        modelIdx: modelIdx
      );
    } else {
      event = DeleteChatModel(
        idx: idx,
        isSubagent: widget.isSubagent,
        modelIdx: modelIdx
      );
    }
    context.read<AgentEditorBloc>().add(event);
  }
}
