import "package:alphchemy/blocs/chat_bloc.dart";
import "package:alphchemy/model/chat_data.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ChatArea extends StatelessWidget {
  const ChatArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state is ChatError) {
          return Center(child: Text(state.message));
        }
        if (state is ChatInitial) {
          return const Center(child: Text("Select or create a chat"));
        }

        final messages = _messagesFrom(state);
        final isSending = state is ChatSending;

        return Column(
          children: [
            Expanded(
              child: ChatMessageList(messages: messages)
            ),
            ChatInput(
              enabled: !isSending,
              onSend: (content) => _sendMessage(context, content)
            )
          ]
        );
      }
    );
  }

  List<ChatMessage> _messagesFrom(ChatState state) {
    if (state is ChatLoaded) return state.messages;
    if (state is ChatSending) return state.messages;
    return [];
  }

  void _sendMessage(BuildContext context, String content) {
    context.read<ChatBloc>().add(SendMessage(content: content));
  }
}

class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;

  const ChatMessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text("No messages yet"));
    }

    final reversedMessages = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      itemCount: reversedMessages.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, i) {
        return ChatMessageBubble(message: reversedMessages[i]);
      }
    );
  }
}

class ChatInput extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool enabled;

  const ChatInput({super.key, required this.onSend, required this.enabled});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
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
              enabled: widget.enabled,
              decoration: const InputDecoration(
                hintText: "Type a message..."
              ),
              onSubmitted: (_) => _handleSend()
            )
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.enabled ? _handleSend : null,
            icon: const Icon(Icons.send)
          )
        ]
      )
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == "user";
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isUser
      ? colorScheme.primaryContainer
      : colorScheme.surfaceContainerHighest;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12)
        ),
        child: SelectableText(message.content)
      )
    );
  }
}
