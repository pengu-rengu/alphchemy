import "package:alphchemy/blocs/chats_bloc.dart";
import "package:alphchemy/blocs/chat_bloc.dart";
import "package:alphchemy/model/chat_summary.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:uuid/uuid.dart";

class ChatSidebar extends StatelessWidget {
  const ChatSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (previous, current) {
        final prevActiveId = _activeChatId(previous);
        final currActiveId = _activeChatId(current);
        return prevActiveId != currActiveId;
      },
      builder: (context, _) => BlocBuilder<ChatsBloc, ChatsState>(
        builder: (context, state) { 
          final chats = <ChatSummary>[];

          if (state is ChatsLoaded) {
            chats.addAll(state.chats);
          }

          return Column(
            children: [
              const ChatSidebarHeader(),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) => ChatSidebarTile(chat: chats[i])
                )
              )
            ]
          );
        }
      )
    );
  }
}

class ChatSidebarHeader extends StatelessWidget {

  const ChatSidebarHeader({super.key});

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Chats",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          ),
          FilledButton.icon(
            onPressed: () => _newChat(context),
            icon: const Icon(Icons.add),
            label: const Text("New Chat")
          )
        ]
      )
    );
  }

  void _newChat(BuildContext context) {
    final id = const Uuid().v4();

    final createEvent = CreateChat(id: id);
    context.read<ChatsBloc>().add(createEvent);

    final loadEvent = LoadChat(id: id);
    context.read<ChatBloc>().add(loadEvent);
  }
}


class ChatSidebarTile extends StatelessWidget {
  final ChatSummary chat;

  const ChatSidebarTile({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    final selected = _activeChatId(context.read<ChatBloc>().state) == chat.id;

    return ListTile(
      title: Text(chat.title),
      selected: selected,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteChat(context)
      ),
      onTap: () => _loadChat(context)
    );
  }

  

  void _loadChat(BuildContext context) { 
    final event = LoadChat(id: chat.id);
    context.read<ChatBloc>().add(event);
  }
  
  void _deleteChat(BuildContext context) {
    final id = chat.id;

    final deleteEvent = DeleteChat(id: id);
    context.read<ChatsBloc>().add(deleteEvent);

    final activeId = _activeChatId(context.read<ChatBloc>().state);
    if (activeId != null && activeId == id) {
      context.read<ChatBloc>().add(const ClearChat());
    }
  }
}

String? _activeChatId(ChatState state) {
    if (state is ChatLoaded) {
      return state.chatId;
    }
    if (state is ChatSending) {
      return state.chatId;
    }
    return null;
  }

