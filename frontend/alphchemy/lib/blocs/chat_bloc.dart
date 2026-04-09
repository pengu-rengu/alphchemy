import "package:alphchemy/model/chat_data.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class ChatEvent {
  const ChatEvent();
}

class LoadChat extends ChatEvent {
  final String id;

  const LoadChat({required this.id});
}

class SendMessage extends ChatEvent {
  final String content;

  const SendMessage({required this.content});
}

class ClearChat extends ChatEvent {
  const ClearChat();
}

sealed class ChatState {
  const ChatState();
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoaded extends ChatState {
  final String chatId;
  final List<ChatMessage> messages;

  const ChatLoaded({required this.chatId, required this.messages});
}

class ChatSending extends ChatState {
  final String chatId;
  final List<ChatMessage> messages;

  const ChatSending({required this.chatId, required this.messages});
}

class ChatError extends ChatState {
  final String message;

  const ChatError({required this.message});
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;

  ChatBloc({required this.repository})
      : super(const ChatInitial()) {
    on<LoadChat>(_onLoad);
    on<SendMessage>(_onSend);
    on<ClearChat>(_onClear);
  }

  Future<void> _onLoad(LoadChat event, Emitter<ChatState> emit) async {
    late ChatState newState;
    try {
      final chatData = await repository.loadChat(event.id);
      newState = ChatLoaded(
        chatId: event.id,
        messages: chatData.messages
      );
    } catch (err) {
      newState = ChatError(message: err.toString());
    }

    emit(newState);
  }

  Future<void> _onSend(SendMessage event, Emitter<ChatState> emit
  ) async {
    final current = state;
    if (current is! ChatLoaded && current is! ChatSending) return;

    final chatId = current is ChatLoaded
      ? current.chatId
      : (current as ChatSending).chatId;

    final sendingState = ChatSending(chatId: chatId, messages: _currentMessages());
    emit(sendingState);

    late ChatState newState;
    try {
      await repository.sendMessage(chatId, event.content);

      final updatedData = await repository.loadChat(chatId);
      newState = ChatLoaded(
        chatId: chatId,
        messages: updatedData.messages
      );
    } catch (err) {
      newState = ChatError(message: err.toString());
    }
    
    emit(newState);
  }

  void _onClear(
    ClearChat event,
    Emitter<ChatState> emit
  ) {
    emit(const ChatInitial());
  }

  List<ChatMessage> _currentMessages() {
    final current = state;
    if (current is ChatLoaded) return current.messages;
    if (current is ChatSending) return current.messages;
    return [];
  }
}
