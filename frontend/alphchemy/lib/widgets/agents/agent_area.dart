import "package:alphchemy/blocs/agents/agent_bloc.dart";
import "package:alphchemy/model/agents/agent_schema.dart";
import "package:alphchemy/widgets/agents/agent_messages.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentArea extends StatelessWidget {
  const AgentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        return switch (state) {
          AgentInitial() => const CenterText("Select or create an agent"),
          AgentError() => CenterText(state.message),
          // ignore: prefer_const_constructors
          AgentLoaded() => AgentContent()
        };
      }
    );
  }
}

class AgentContent extends StatelessWidget {
  const AgentContent({super.key});

  @override
  Widget build(BuildContext context) {
    // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
    // ignore: prefer_const_constructors
    return Column(
      // ignore: prefer_const_literals_to_create_immutables
      children: [
        // ignore: prefer_const_constructors
        AgentThreadTabs(),
        const Divider(height: 1.0),
        // ignore: prefer_const_constructors
        Expanded(child: AgentMessageList()),
        const Divider(height: 1.0),
        // ignore: prefer_const_constructors
        CurrentPrompt(),
        // ignore: prefer_const_constructors
        PromptInput()
      ]
    );
  }
}

class AgentThreadTabs extends StatelessWidget {
  const AgentThreadTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(children: (() {
        final state = context.read<AgentBloc>().state as AgentLoaded;
        final agentIds = state.agentSys.agentIds;
        final widgets = <Widget>[];
        final nAgents = agentIds.length;

        for (var i = 0; i < nAgents; i++) {
          final agentId = agentIds[i];
          final selected = agentId == state.activeThread;

          widgets.add(ChoiceChip(
            label: selected ? InvertedText(agentId) : NormalText(agentId),
            selected: selected,
            onSelected: (_) {
              final event = SelectThread(agentId: agentId);
              context.read<AgentBloc>().add(event);
            }
          ));

          if (i < nAgents - 1) {
            widgets.add(const SizedBox(width: 5.0));
          }
        }

        return widgets;
      })())
    );
  }
}

class PromptInput extends StatefulWidget {
  const PromptInput({super.key});

  @override
  State<PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends State<PromptInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final event = SendUserPrompt(content: text);
    context.read<AgentBloc>().add(event);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              
              decoration: const InputDecoration(
              isDense: false,
                hintText: "Type a prompt..."
              ),
              onSubmitted: state.agentSys.status == AgentStatus.idle ? (_) => _handleSend() : null
            )
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: state.agentSys.status == AgentStatus.idle ? _handleSend : null,
            icon: const NormalIcon(Icons.send)
          )
        ]
      )
    );
  }
}

class CurrentPrompt extends StatelessWidget {
  const CurrentPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final prompt = state.agentSys.userPrompt;

    return prompt == null || prompt.isEmpty ? const SizedBox.shrink() : Padding(
      padding: const EdgeInsets.all(10.0),
      child: SizedBox(
        width: double.infinity,
        child: PaddedCard(child: Align(
          alignment: Alignment.centerLeft,
          child: NormalText(prompt)
        ))
      )
    );
  }
}
