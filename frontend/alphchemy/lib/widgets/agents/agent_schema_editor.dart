import "package:alphchemy/blocs/agents/agent_editor_bloc.dart";
import "package:alphchemy/model/agents/agent_schema.dart";
import "package:alphchemy/widgets/synced_text_field.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: NormalText(text)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            LargeText(title),
            const SizedBox(width: 10.0),
            IconButton(
              onPressed: () => _addAgent(context),
              icon: const NormalIcon(Icons.add)
            )
          ]
        ),
        const SizedBox(height: 12),
        ...(() {
          if (agents.isEmpty) {
            return const [NormalText("No agents")];
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
                icon: const NormalIcon(Icons.delete_outline),
                tooltip: "Remove agent",
                onPressed: () => _remove(context)
              )
            ]
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const FieldLabel(text: "Max Context Length"),
              Expanded(child: SyncedTextField(
                text: "${agent.maxContextLen}",
                onChanged: (value) => _updateField(context, "maxContextLen", value, intValue: true)
              ))
            ]
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const FieldLabel(text: "# Of Messages to Delete"),
              Expanded(child: SyncedTextField(
                text: "${agent.nDelete}",
                onChanged: (value) => _updateField(context, "nDelete", value, intValue: true)
              ))
            ]
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const FieldLabel(text: "Chat Model"),
              Expanded(child: SyncedTextField(
                text: agent.chatModel,
                onChanged: (value) => _updateField(context, "chatModel", value)
              ))
            ]
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const FieldLabel(text: "Chat Fallback Model"),
              Expanded(child: SyncedTextField(
                text: agent.chatFallbackModel,
                onChanged: (value) => _updateField(context, "chatFallbackModel", value)
              ))
            ]
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const FieldLabel(text: "Summarize Model"),
              Expanded(child: SyncedTextField(
                text: agent.summarizeModel,
                onChanged: (value) => _updateField(context, "summarizeModel", value)
              ))
            ]
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const FieldLabel(text: "Summarize Fallback Model"),
              Expanded(child: SyncedTextField(
                text: agent.summarizeFallbackModel,
                onChanged: (value) => _updateField(context, "summarizeFallbackModel", value)
              ))
            ]
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel(text: "Additional Instructions"),
              Expanded(child: SyncedTextField(
                text: agent.additionalInstructions,
                minLines: 3,
                maxLines: 10,
                onChanged: (value) => _updateField(context, "additionalInstructions", value)
              ))
            ]
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
