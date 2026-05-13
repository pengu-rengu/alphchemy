import "package:alphchemy/blocs/agent_bloc.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/widgets/agents/agent_messages.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentArea extends StatelessWidget {
  const AgentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (BuildContext context, AgentState state) {
        if (state is AgentInitial) {
          return const Center(child: NormalText("Select or create an agent"));
        }
        if (state is AgentError) {
          return Center(child: NormalText(state.message));
        }
        // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
        // ignore: prefer_const_constructors
        return AgentSystemView();
      }
    );
  }
}

class AgentSystemView extends StatelessWidget {
  const AgentSystemView({super.key});

  @override
  Widget build(BuildContext context) {
    // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
    // ignore: prefer_const_constructors
    return Column(
      // ignore: prefer_const_literals_to_create_immutables
      children: [
        // ignore: prefer_const_constructors
        AgentThreadTabs(),
        const Divider(),
        // ignore: prefer_const_constructors
        Expanded(child: AgentMessageList()),
        const PromptInput()
      ]
    );
  }
}

class AgentThreadTabs extends StatelessWidget {
  const AgentThreadTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final agentIds = state.agentSys.agentIds;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(children: (() {
        final widgets = <Widget>[];
        final nAgents = agentIds.length;

        for (var i = 0; i < nAgents; i++) {
          final agentId = agentIds[i];
          final selected = agentId == state.activeThread;

          widgets.add(ChoiceChip(
            label: selected ? InvertedText(agentId) : NormalText(agentId),
            selected: selected,
            onSelected: (_) => _select(context, agentId),
          ));

          if (i < nAgents - 1) {
            widgets.add(const SizedBox(width: 5.0));
          }
        }

        return widgets;
      })())
    );
  }

  void _select(BuildContext context, String agentId) {
    final event = SelectThread(agentId: agentId);
    context.read<AgentBloc>().add(event);
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
    if (text.isEmpty) {
      return;
    }

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
              onSubmitted: (_) => _handleSend()
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
