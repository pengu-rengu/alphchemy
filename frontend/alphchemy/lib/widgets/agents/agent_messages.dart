import "dart:convert";

import "package:alphchemy/blocs/agent_bloc.dart";
import "package:alphchemy/model/agent_system/agent_context.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentMessageList extends StatelessWidget {
  const AgentMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AgentBloc>().state as AgentLoaded;
    final messages = state.agentSys.contexts.threads[state.activeThread] ?? const [];

    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }

    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      itemCount: reversed.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    final text = _textFor(message);

    final maxWidth = MediaQuery.of(context).size.width * 0.7;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8)
      ),
      child: SelectableText(text)
    );
  }

  static String _textFor(ContextMessage message) {
    if (message is UserMessage) {
      return _textForUser(message);
    }

    if (message is ThoughtMessage) {
      return message.thought.trim();
    }

    if (message is CommandMessage) {
      return _textForCommand(message);
    }

    return "";
  }

  static String _textForUser(UserMessage message) {
    final personalOutput = message.personalOutput.trim();
    final globalOutput = message.globalOutput.trim();
    return "PERSONAL OUTPUT:\n\n$personalOutput\n\nGLOBAL OUTPUT:\n\n$globalOutput".trim();
  }

  static String _textForCommand(CommandMessage message) {
    final buffer = StringBuffer();
    buffer.writeln("COMMAND: ${message.command}");
    if (message.params.isEmpty) {
      return buffer.toString().trim();
    }

    buffer.writeln();
    const encoder = JsonEncoder.withIndent("  ");
    final text = encoder.convert(message.params);
    buffer.write(text);
    return buffer.toString().trim();
  }
}
