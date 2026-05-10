import "package:alphchemy/blocs/agent_editor_bloc.dart";
import "package:alphchemy/model/agent_system.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 6),
        child: Text(text)
      )
    );
  }
}

class AgentSystemForm extends StatelessWidget {
  const AgentSystemForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentEditorBloc, AgentEditorState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AgentSectionCard(
                title: "Agents",
                agents: state.schema.agents,
                isSubagent: false
              ),
              const SizedBox(height: 16),
              AgentSectionCard(
                title: "Subagent pool",
                agents: state.schema.subagentPool,
                isSubagent: true
              )
            ]
          )
        );
      }
    );
  }
}

class AgentSectionCard extends StatelessWidget {
  final String title;
  final List<AgentConfig> agents;
  final bool isSubagent;

  const AgentSectionCard({
    super.key,
    required this.title,
    required this.agents,
    required this.isSubagent
  });

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleMedium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            ..._cards()
          ]
        )
      )
    );
  }

  List<Widget> _cards() {
    if (agents.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text("No agents")
        )
      ];
    }
    final cards = <Widget>[];
    for (var i = 0; i < agents.length; i = i + 1) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AgentConfigCard(
          agent: agents[i],
          index: i,
          isSubagent: isSubagent
        )
      );
      cards.add(card);
    }
    return cards;
  }

  void _addAgent(BuildContext context) {
    final event = AddAgent(isSubagent: isSubagent);
    context.read<AgentEditorBloc>().add(event);
  }
}

class AgentConfigCard extends StatelessWidget {
  final AgentConfig agent;
  final int index;
  final bool isSubagent;

  const AgentConfigCard({
    super.key,
    required this.agent,
    required this.index,
    required this.isSubagent
  });

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const FieldLabel(text: "id"),
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
                const FieldLabel(text: "max_context_len"),
                Expanded(
                  child: SyncedTextField(
                    text: "${agent.maxContextLen}",
                    onChanged: (value) => _updateInt(context, "maxContextLen", value)
                  )
                )
              ]
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const FieldLabel(text: "n_delete"),
                Expanded(
                  child: SyncedTextField(
                    text: "${agent.nDelete}",
                    onChanged: (value) => _updateInt(context, "nDelete", value)
                  )
                )
              ]
            ),
            const SizedBox(height: 12),
            ModelChipsEditor(
              label: "chat_models",
              models: agent.chatModels,
              index: index,
              isSubagent: isSubagent,
              listKey: "chat"
            ),
            const SizedBox(height: 8),
            ModelChipsEditor(
              label: "summarize_models",
              models: agent.summarizeModels,
              index: index,
              isSubagent: isSubagent,
              listKey: "summarize"
            )
          ]
        )
      )
    );
  }

  void _updateField(BuildContext context, String field, String value) {
    final event = UpdateAgentField(
      index: index,
      isSubagent: isSubagent,
      field: field,
      value: value
    );
    context.read<AgentEditorBloc>().add(event);
  }

  void _updateInt(BuildContext context, String field, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    final event = UpdateAgentField(
      index: index,
      isSubagent: isSubagent,
      field: field,
      value: parsed
    );
    context.read<AgentEditorBloc>().add(event);
  }

  void _remove(BuildContext context) {
    final event = RemoveAgent(index: index, isSubagent: isSubagent);
    context.read<AgentEditorBloc>().add(event);
  }
}

class ModelChipsEditor extends StatefulWidget {
  final String label;
  final List<String> models;
  final int index;
  final bool isSubagent;
  final String listKey;

  const ModelChipsEditor({
    super.key,
    required this.label,
    required this.models,
    required this.index,
    required this.isSubagent,
    required this.listKey
  });

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
              Wrap(spacing: 6, runSpacing: 6, children: _chips()),
              const SizedBox(height: 6),
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

  List<Widget> _chips() {
    final chips = <Widget>[];
    for (var i = 0; i < widget.models.length; i = i + 1) {
      final modelIndex = i;
      final chip = InputChip(
        label: Text(widget.models[i]),
        onDeleted: () => _remove(modelIndex)
      );
      chips.add(chip);
    }
    return chips;
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    final event = AddModel(
      index: widget.index,
      isSubagent: widget.isSubagent,
      list: widget.listKey,
      model: value
    );
    context.read<AgentEditorBloc>().add(event);
    _controller.clear();
  }

  void _remove(int modelIndex) {
    final event = RemoveModel(
      index: widget.index,
      isSubagent: widget.isSubagent,
      list: widget.listKey,
      modelIndex: modelIndex
    );
    context.read<AgentEditorBloc>().add(event);
  }
}
