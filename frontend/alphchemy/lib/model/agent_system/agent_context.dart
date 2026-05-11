import "dart:convert";

sealed class ContextMessage {
  const ContextMessage();

  static List<ContextMessage> parseJson(Map<String, dynamic> json) {

    if (json["role"] == "user") {
      return [UserMessage.fromJson(json)];
    } else {
      return _parseAssistantJson(json);
    }
  }

  static List<ContextMessage> _parseAssistantJson(Map<String, dynamic> json) {
    try {
      final decoded = jsonDecode(json["model_output"] as String);
      final modelOutput = decoded as Map<String, dynamic>;
      final messages = <ContextMessage>[];

      final thoughtMessage = ThoughtMessage(thought: modelOutput["thought"] as String);
      messages.add(thoughtMessage);

      for (final commandItem in modelOutput["commands"]) {
        final commandMessage = CommandMessage.fromJson(commandItem as Map<String, dynamic>);
        messages.add(commandMessage);
      }
      return messages;
    } catch (error) {
      final message = ThoughtMessage(thought: error.toString());
      return [message];
    }
  }
}

class UserMessage extends ContextMessage {
  final String personalOutput;
  final String globalOutput;

  const UserMessage({required this.personalOutput, required this.globalOutput});

  factory UserMessage.fromJson(Map<String, dynamic> json) {
    return UserMessage(
      personalOutput: json["personal_output"] as String,
      globalOutput: json["global_output"] as String
    );
  }
}

class ThoughtMessage extends ContextMessage {
  final String thought;

  const ThoughtMessage({required this.thought});
}

class CommandMessage extends ContextMessage {
  final String command;
  final Map<String, dynamic> params;

  const CommandMessage({required this.command, required this.params});

  factory CommandMessage.fromJson(Map<String, dynamic> json) {
    final params = Map<String, dynamic>.from(json);
    params.remove("command");

    return CommandMessage(
      command: json["command"] as String,
      params: params,
    );
  }
}
class AgentContexts {
  final Map<String, List<ContextMessage>> threads;

  const AgentContexts({required this.threads});

  factory AgentContexts.fromJson(Map<String, dynamic> json, List<String> agentIds) {
    final threads = <String, List<ContextMessage>>{};
    for (final agentId in agentIds) {
      threads[agentId] = const <ContextMessage>[];
    }

    for (final entry in json.entries) {
      final messageItems = entry.value as List<dynamic>;
      final messages = <ContextMessage>[];

      for (final messageItem in messageItems) {
        final messageJson = messageItem as Map<String, dynamic>;
        final parsedMessages = ContextMessage.parseJson(messageJson);
        messages.addAll(parsedMessages);
      }

      threads[entry.key] = List<ContextMessage>.unmodifiable(messages);
    }

    final threadMap = Map<String, List<ContextMessage>>.unmodifiable(threads);
    return AgentContexts(threads: threadMap);
  }
}
