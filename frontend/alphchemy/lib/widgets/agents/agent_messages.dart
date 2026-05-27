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
    final summary = state.agentSys.summaries[state.activeThread]!;
    final hasSummary = summary.isNotEmpty;
    final messages = state.agentSys.contexts.threads[state.activeThread] ?? const [];

    if (messages.isEmpty && !showIndicator && !hasSummary) {
      return const CenterText("No messages yet");
    }

    return AgentMessageItems(
      messages: messages.reversed.toList(),
      showIndicator: showIndicator,
      summary: summary
    );
  }
}

class AgentMessageItems extends StatelessWidget {
  final List<ContextMessage> messages;
  final bool showIndicator;
  final String summary;

  const AgentMessageItems({super.key, required this.messages, required this.showIndicator, required this.summary});

  @override
  Widget build(BuildContext context) {
    final hasSummary = summary.isNotEmpty;
    var itemCount = messages.length + (hasSummary ? 1 : 0);
    if (showIndicator) {
      itemCount++;
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(10.0),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (showIndicator && i == 0) {
          return const WorkingIndicator();
        }
        if (hasSummary && i == itemCount - 1) {
          return SummaryMessageItem(summary: summary);
        }
        return AgentMessageBubble(message: messages[showIndicator ? i - 1 : i]);
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
      OutputMessage() => OutputMessageItem(message: message as OutputMessage),
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
    final thought = message.thought.trim();
    return ExpansionTile(
      title: NormalText(thought, maxLines: 1),
      leading: const NormalIcon(Icons.psychology),
      children: [
        const SizedBox(height: 10.0),
        NormalText(thought)
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

class SummaryMessageItem extends StatelessWidget {
  final String summary;

  const SummaryMessageItem({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: ExpansionTile(
      title: const NormalText("Summary"),
      leading: const NormalIcon(Icons.summarize),
      children: [
        const SizedBox(height: 10.0),
        NormalText(summary.trim())
      ]
    ));
  }
}

class OutputMessageItem extends StatelessWidget {
  final OutputMessage message;

  const OutputMessageItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final personalOutput = message.personalOutput;
    final globalOutput = message.globalOutput;

    return ExpansionTile(
      title: const NormalText("Output"),
      leading: const NormalIcon(Icons.output),
      shape: const Border(),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (personalOutput.isNotEmpty) ...[
                  const NormalText("PERSONAL OUTPUT:"),
                  NormalText(personalOutput.trim()),
                ],
                const SizedBox(height: 10),
                if (globalOutput.isNotEmpty) ...[
                  const NormalText("GLOBAL OUTPUT:"),
                  NormalText(globalOutput.trim())
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
