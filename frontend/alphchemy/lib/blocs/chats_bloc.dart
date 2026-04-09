import "package:alphchemy/model/chat_data.dart";
import "package:alphchemy/model/chat_summary.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class ChatsEvent {
  const ChatsEvent();
}

class LoadChats extends ChatsEvent {
  const LoadChats();
}

class CreateChat extends ChatsEvent {
  final String id;

  const CreateChat({required this.id});
}

class DeleteChat extends ChatsEvent {
  final String id;

  const DeleteChat({required this.id});
}

sealed class ChatsState {
  const ChatsState();
}

class ChatsInitial extends ChatsState {
  const ChatsInitial();
}

class ChatsLoaded extends ChatsState {
  final List<ChatSummary> chats;

  const ChatsLoaded({required this.chats});
}

class ChatsError extends ChatsState {
  final String message;

  const ChatsError({required this.message});
}

class ChatsBloc extends Bloc<ChatsEvent, ChatsState> {
  final ChatRepository repository;

  ChatsBloc({required this.repository})
      : super(const ChatsInitial()) {
    on<LoadChats>(_onLoad);
    on<CreateChat>(_onCreate);
    on<DeleteChat>(_onDelete);
  }

  Future<void> _onLoad(LoadChats event, Emitter<ChatsState> emit) async {
    late ChatsState newState;
    try {
      final chats = await repository.loadSummaries();
      newState = ChatsLoaded(chats: chats);
    } catch (err) {
      newState = ChatsError(message: err.toString());
    } finally {
      emit(newState);
    }
  }

  Future<void> _onCreate(CreateChat event, Emitter<ChatsState> emit) async {
    late ChatsState newState;

    try {
      await repository.saveChat(event.id, ChatData.blank());
      final chats = await repository.loadSummaries();
      newState = ChatsLoaded(chats: chats);
    } catch (err) {
      newState = ChatsError(message: err.toString());
    }

    emit(newState);
  }

  Future<void> _onDelete(DeleteChat event, Emitter<ChatsState> emit) async {
    late ChatsState newState;

    try {
      await repository.delete(event.id);
      final chats = await repository.loadSummaries();
      newState = ChatsLoaded(chats: chats);
    } catch (err) {
      newState = ChatsError(message: err.toString());
    } finally {
      emit(newState);
    }
  }
}
