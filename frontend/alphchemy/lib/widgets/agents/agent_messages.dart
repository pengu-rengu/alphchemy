import "dart:convert";

import "package:alphchemy/blocs/agent_bloc.dart";
import "package:alphchemy/model/agent_system/agent_contexts.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentMessageList extends StatelessWidget {
  const AgentMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final messages = state.agentSys.contexts.threads[state.activeThread] ?? const [];

    if (messages.isEmpty) {
      return const Center(child: NormalText("No messages yet"));
    }

    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        return AgentMessageBubble(message: reversed[i]);
      }
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
