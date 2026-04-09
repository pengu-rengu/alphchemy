import "package:alphchemy/model/chat_data.dart";
import "package:alphchemy/model/chat_summary.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

class ChatRepository {
  final Map<String, _StoredChat> _store = {};

  Future<List<ChatSummary>> loadSummaries() async {
    final summaries = _store.values.map((stored) => stored.summary).toList();
    summaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return summaries;
  }

  Future<ChatData> loadChat(String id) async {
    final stored = _store[id];
    if (stored == null) {
      throw Exception("Chat not found: $id");
    }
    return stored.data;
  }

  Future<void> saveChat(String id, ChatData data) async {
    final existing = _store[id];
    final title = existing?.summary.title ?? "New Chat";
    final createdAt = existing?.summary.createdAt ?? DateTime.now();
    _store[id] = _StoredChat(
      summary: ChatSummary(
        id: id,
        title: title,
        createdAt: createdAt
      ),
      data: data
    );
  }

  Future<void> delete(String id) async {
    _store.remove(id);
  }
  
  Future<ChatMessage> sendMessage(String chatId, String content) async {
    final stored = _store[chatId];
    if (stored == null) {
      throw Exception("Chat not found: $chatId");
    }

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: "user",
      content: content,
      createdAt: DateTime.now()
    );

    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      role: "assistant",
      content: "This is a mock response to: $content",
      createdAt: DateTime.now()
    );

    final updatedMessages = [
      ...stored.data.messages,
      userMessage,
      assistantMessage
    ];
    final updatedData = ChatData(messages: updatedMessages);

    final isFirstMessage = stored.data.messages.isEmpty;
    final titleEnd = content.length > 30 ? 30 : content.length;
    final title = isFirstMessage
      ? content.substring(0, titleEnd)
      : stored.summary.title;

    _store[chatId] = _StoredChat(
      summary: ChatSummary(
        id: chatId,
        title: title,
        createdAt: stored.summary.createdAt
      ),
      data: updatedData
    );

    return assistantMessage;
  }
}

class _StoredChat {
  final ChatSummary summary;
  final ChatData data;

  const _StoredChat({required this.summary, required this.data});
}
