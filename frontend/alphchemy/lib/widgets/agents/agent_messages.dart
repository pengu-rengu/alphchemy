import "dart:async";
import "dart:convert";

import "package:alphchemy/blocs/agents/agent_bloc.dart";
import "package:alphchemy/main.dart";
import "package:alphchemy/model/agents/agent_contexts.dart";
import "package:alphchemy/model/agents/agent_schema.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentMessageList extends StatelessWidget {
  const AgentMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final showIndicator = state.agentSys.status == AgentStatus.working;
    final messages = state.agentSys.contexts.threads[state.activeThread] ?? const [];

    return messages.isEmpty && !showIndicator
      ? const CenterText("No messages yet")
      : AgentMessageItems(
          messages: messages.reversed.toList(),
          showIndicator: showIndicator
        );
  }
}

class AgentMessageItems extends StatelessWidget {
  final List<ContextMessage> messages;
  final bool showIndicator;

  const AgentMessageItems({super.key, required this.messages, required this.showIndicator});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      itemCount: messages.length + (showIndicator ? 1 : 0),
      itemBuilder: (context, i) {
        if (showIndicator && i == 0) {
          return const WorkingIndicator();
        }
        final idx = showIndicator ? i - 1 : i;
        return AgentMessageBubble(message: messages[idx]);
      }
    );
  }
}

class WorkingIndicator extends StatefulWidget {
  const WorkingIndicator({super.key});

  @override
  State<WorkingIndicator> createState() => _WorkingIndicatorState();
}

class _WorkingIndicatorState extends State<WorkingIndicator> {
  static const List<String> _ellipses = ["", ".", "..", "..."];

  int _phase = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), _tick);
  }

  void _tick(Timer timer) {
    setState(() {
      _phase = (_phase + 1) % 4;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).extension<AppColors>()!.fgColor1;
    final circleVisible = _phase % 2 == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: circleVisible ? 1.0 : 0.0,
              child: Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle
                )
              )
            ),
            const SizedBox(width: 8.0),
            NormalText("working${_ellipses[_phase]}")
          ]
        )
      )
    );
  }
}

class AgentMessageBubble extends StatelessWidget {
  final ContextMessage message;

  const AgentMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: switch (message) {
      UserMessage() => OutputMessageItem(message: message as UserMessage),
      ThoughtMessage() => ThoughtMessageItem(message: message as ThoughtMessage),
      CommandMessage() => CommandMessageItem(message: message as CommandMessage)
    });
  }
}

class ThoughtMessageItem extends StatelessWidget {
  final ThoughtMessage message;

  const ThoughtMessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final lines = message.thought.trim().split("\n");
    return ExpansionTile(
      title: NormalText(lines.isNotEmpty ? lines.first : "", maxLines: 1),
      leading: const NormalIcon(Icons.psychology),
      children: [
        const SizedBox(height: 10.0),
        NormalText(message.thought.trim())
      ],
    );
  }
}

class CommandMessageItem extends StatelessWidget {
  final CommandMessage message;

  const CommandMessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent("  ");
    final paramsText = encoder.convert(message.params);

    return ExpansionTile(
      title: NormalText(message.command),
      leading: const NormalIcon(Icons.terminal),
      children: [
        const SizedBox(height: 5.0),
        NormalText(paramsText)
      ],
    );
  }
}

class OutputMessageItem extends StatelessWidget {
  final UserMessage message;

  const OutputMessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const NormalText("Output"),
      leading: const NormalIcon(Icons.output),
      shape: const Border(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.personalOutput.isNotEmpty) ...[
                  const NormalText("PERSONAL OUTPUT:"),
                  NormalText(message.personalOutput.trim()),
                  if (message.globalOutput.isNotEmpty) const SizedBox(height: 10),
                ],
                if (message.globalOutput.isNotEmpty) ...[
                  const NormalText("GLOBAL OUTPUT:"),
                  NormalText(message.globalOutput.trim())
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
