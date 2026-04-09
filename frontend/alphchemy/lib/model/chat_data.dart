class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  const ChatMessage({required this.id, required this.role, required this.content, required this.createdAt});
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json["id"] as String,
      role: json["role"] as String,
      content: json["content"] as String,
      createdAt: DateTime.parse(json["created_at"] as String)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "role": role,
      "content": content,
      "created_at": createdAt.toIso8601String()
    };
  }
}

class ChatData {
  final List<ChatMessage> messages;

  const ChatData({required this.messages});

  factory ChatData.fromJson(Map<String, dynamic> json) {
    final rawMessages = json["messages"] as List<dynamic>? ?? [];
    final parsed = rawMessages.map(
      (msg) => ChatMessage.fromJson(msg as Map<String, dynamic>)
    );
    return ChatData(messages: parsed.toList());
  }

  factory ChatData.blank() {
    return const ChatData(messages: []);
  }

  Map<String, dynamic> toJson() {
    return {
      "messages": messages.map((msg) => msg.toJson()).toList()
    };
  }
}
