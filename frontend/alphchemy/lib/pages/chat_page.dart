import "package:alphchemy/blocs/chat_bloc.dart";
import "package:alphchemy/blocs/chats_bloc.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:alphchemy/widgets/chat/chat_area.dart";
import "package:alphchemy/widgets/chat/chat_sidebar.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ChatRepository>();
    return BlocProvider(
      create: (_) => ChatBloc(repository: repository),
      child: const PageScaffold(
        selectedIdx: 1,
        child: ChatBody()
      )
    );
  }
}

class ChatBody extends StatelessWidget {
  const ChatBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previousState, currentState) {
        final wasSending = previousState is ChatSending;
        final isLoaded = currentState is ChatLoaded;
        return wasSending && isLoaded;
      },
      listener: (context, state) {
        context.read<ChatsBloc>().add(const LoadChats());
      },
      child: const Row(
        children: [
          Expanded(child: ChatArea()),
          VerticalDivider(width: 1),
          SizedBox(
            width: 280,
            child: ChatSidebar()
          )
        ]
      )
    );
  }
}
