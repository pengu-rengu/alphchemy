import "package:alphchemy/blocs/agent_bloc.dart";
import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentArea extends StatelessWidget {
  const AgentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (BuildContext context, AgentState state) {
        if (state is AgentInitial) {
          return const Center(child: Text("Select or create an agent"));
        }
        if (state is AgentError) {
          return Center(child: Text(state.message));
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
    final agentOrder = state.agentSys.schema.agents.map((config) => config.id).toList();
    final activeThreadId = state.activeThread;

    if (agentOrder.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("No agents configured")
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(children: _tabs(context, agentOrder, activeThreadId))
    );
  }

  List<Widget> _tabs(BuildContext context, List<String> agentOrder, String activeThreadId) {
    final widgets = <Widget>[];
    for (var i = 0; i < agentOrder.length; i++) {
      final agentId = agentOrder[i];
      final selected = agentId == activeThreadId;
      final tab = Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(agentId),
          selected: selected,
          onSelected: (_) => _select(context, agentId)
        )
      );
      widgets.add(tab);
    }
    return widgets;
  }

  void _select(BuildContext context, String agentId) {
    final event = SelectThread(agentId: agentId);
    context.read<AgentBloc>().add(event);
  }
}

class AgentMessageList extends StatelessWidget {
  const AgentMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final agentState = state.agentSys.state;
    if (agentState == null) {
      return const Center(child: Text("No context yet"));
    }

    final contexts = agentState["agent_contexts"] as Map<String, dynamic>?;
    final threadMessages = contexts?[state.activeThread] as List<dynamic>?;
    final messages = threadMessages ?? const [];

    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }
    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      itemCount: reversed.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, i) {
        final message = reversed[i] as Map<String, dynamic>;
        return AgentMessageBubble(message: message);
      }
    );
  }
}

class AgentMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const AgentMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message["role"] == "user";
    final text = _textFor(message);

    final maxWidth = MediaQuery.of(context).size.width * 0.7;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8)
        ),
        child: SelectableText(text)
      )
    );
  }

  static String _textFor(Map<String, dynamic> message) {
    final role = message["role"] as String;
    if (role == "assistant") {
      return (message["model_output"] as String? ?? "").trim();
    }
    final personalOutput = message["personal_output"] as String? ?? "";
    final globalOutput = message["global_output"] as String? ?? "";
    return "PERSONAL OUTPUT:\n\n$personalOutput\n\nGLOBAL OUTPUT:\n\n$globalOutput".trim();
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
    final bloc = context.read<AgentBloc>();
    final state = bloc.state as AgentLoaded;
    if (!_canSend(state)) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final event = SendUserPrompt(content: text);
    bloc.add(event);
    _controller.clear();
  }

  bool _canSend(AgentLoaded state) {
    if (state.agentSys.status != AgentStatus.idle) return false;
    return state.agentSys.userPrompt == null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final canSend = _canSend(state);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: "Type a prompt..."),
              onSubmitted: (_) => _handleSend()
            )
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: canSend ? _handleSend : null,
            icon: const Icon(Icons.send)
          )
        ]
      )
    );
  }
}
