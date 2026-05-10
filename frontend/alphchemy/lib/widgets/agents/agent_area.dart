import "dart:convert";

import "package:alphchemy/blocs/agents_bloc.dart";
import "package:alphchemy/model/agent.dart";
import "package:alphchemy/model/agents_state.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentArea extends StatelessWidget {
  const AgentArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentsBloc, AgentsBlocState>(
      builder: (context, state) {
        if (state is! AgentsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = state.activeData;
        if (data == null) {
          return const Center(child: Text("Select or create an agent"));
        }
        return AgentSystemView(
          data: data,
          activeThreadId: state.activeThreadId,
          sending: state.sending
        );
      }
    );
  }
}

class AgentSystemView extends StatelessWidget {
  final Agent data;
  final String? activeThreadId;
  final bool sending;

  const AgentSystemView({
    super.key,
    required this.data,
    required this.activeThreadId,
    required this.sending
  });

  @override
  Widget build(BuildContext context) {
    final order = _agentIds(data);
    final agentState = data.state;
    final contexts = agentState?.agentContexts ?? const <String, List<AgentMessage>>{};
    final messages = _messagesFor(activeThreadId, contexts);
    final canType = activeThreadId != null;
    final canSend = _canSend(data, canType);
    final submission = agentState?.finalSubmission;
    return Column(
      children: [
        AgentThreadTabs(agentOrder: order, activeThreadId: activeThreadId),
        const Divider(height: 1),
        if (submission != null) AgentSubmissionPanel(submission: submission),
        Expanded(
          child: agentState == null
              ? AgentEmptyState(status: data.status.label)
              : AgentMessageList(messages: messages)
        ),
        AgentInput(
          canType: canType,
          canSend: canSend,
          onSend: (content) => _send(context, content)
        )
      ]
    );
  }

  static List<String> _agentIds(Agent data) {
    final stateOrder = data.state?.agentOrder ?? const <String>[];
    if (stateOrder.isNotEmpty) {
      return stateOrder;
    }

    final mapped = data.schema.agents.map((agent) => agent.id);
    return mapped.toList();
  }

  static List<AgentMessage> _messagesFor(
    String? threadId,
    Map<String, List<AgentMessage>> contexts
  ) {
    if (threadId == null) return const [];
    return contexts[threadId] ?? const [];
  }

  bool _canSend(Agent data, bool canType) {
    if (!canType) {
      return false;
    }
    if (sending) {
      return false;
    }
    if (!data.status.canReceivePrompt) {
      return false;
    }
    return data.userPrompt == null;
  }

  void _send(BuildContext context, String content) {
    final event = SendUserMessage(content: content);
    context.read<AgentsBloc>().add(event);
  }
}

class AgentEmptyState extends StatelessWidget {
  final String status;

  const AgentEmptyState({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final text = status == "created" ? "Initializing agent" : "No context yet";
    return Center(child: Text(text));
  }
}

class AgentThreadTabs extends StatelessWidget {
  final List<String> agentOrder;
  final String? activeThreadId;

  const AgentThreadTabs({
    super.key,
    required this.agentOrder,
    required this.activeThreadId
  });

  @override
  Widget build(BuildContext context) {
    if (agentOrder.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("No agents configured")
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: _tabs(context))
    );
  }

  List<Widget> _tabs(BuildContext context) {
    final widgets = <Widget>[];
    for (var i = 0; i < agentOrder.length; i = i + 1) {
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
    context.read<AgentsBloc>().add(event);
  }
}

class AgentMessageList extends StatelessWidget {
  final List<AgentMessage> messages;

  const AgentMessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }
    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      itemCount: reversed.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, i) => AgentMessageBubble(message: reversed[i])
    );
  }
}

class AgentMessageBubble extends StatelessWidget {
  final AgentMessage message;

  const AgentMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final text = _renderText();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final isUserPrompt = message.isUserPrompt;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isUserPrompt
      ? colorScheme.primaryContainer
      : colorScheme.surfaceContainerLow;
    final textColor = isUserPrompt
      ? colorScheme.onPrimaryContainer
      : colorScheme.onSurfaceVariant;
    final opacity = isUserPrompt ? 1.0 : 0.72;
    final maxWidth = MediaQuery.of(context).size.width * 0.7;
    return Align(
      alignment: isUserPrompt ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: EdgeInsets.symmetric(
          vertical: isUserPrompt ? 10 : 8,
          horizontal: isUserPrompt ? 14 : 12
        ),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(8)
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: isUserPrompt ? 12 : 11
          )
        )
      )
    );
  }

  String _renderText() {
    if (message.role == "assistant") {
      return message.modelOutput.trim();
    }
    final personal = _renderPersonalText();
    final global = message.globalOutput.trim();
    if (global.isEmpty) {
      return personal;
    }
    if (personal.isEmpty) {
      return global;
    }
    return "$personal\n$global";
  }

  String _renderPersonalText() {
    final personal = message.personalOutput.trim();
    if (!message.isUserPrompt) {
      return personal;
    }
    if (!personal.startsWith("[USER]")) {
      return personal;
    }

    return personal.substring(6).trim();
  }
}

class AgentInput extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool canType;
  final bool canSend;

  const AgentInput({
    super.key,
    required this.onSend,
    required this.canType,
    required this.canSend
  });

  @override
  State<AgentInput> createState() => _AgentInputState();
}

class _AgentInputState extends State<AgentInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!widget.canSend) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.canType,
              decoration: const InputDecoration(hintText: "Type a prompt..."),
              onSubmitted: (_) => _handleSend()
            )
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.canSend ? _handleSend : null,
            icon: const Icon(Icons.send)
          )
        ]
      )
    );
  }
}

class AgentSubmissionPanel extends StatelessWidget {
  final AgentSubmission submission;

  const AgentSubmissionPanel({super.key, required this.submission});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const encoder = JsonEncoder.withIndent("  ");
    final text = encoder.convert(submission.content);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "${submission.type} submission",
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600
            )
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 12
            )
          )
        ]
      )
    );
  }
}
