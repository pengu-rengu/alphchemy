import "dart:async";

import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/agent_system.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class AgentEvent {
  const AgentEvent();
}

class LoadAgent extends AgentEvent {
  final int id;

  const LoadAgent({required this.id});
}


class SelectThread extends AgentEvent {
  final String agentId;

  const SelectThread({required this.agentId});
}

class SendUserPrompt extends AgentEvent {
  final String content;

  const SendUserPrompt({required this.content});
}

class UpdateAgent extends AgentEvent {
  final Map<String, dynamic> row;

  const UpdateAgent({required this.row});
}

class LoadError extends AgentEvent {
  final String message;

  const LoadError({required this.message});
}

sealed class AgentState {
  const AgentState();
}

class AgentInitial extends AgentState {
  const AgentInitial();
}

class AgentLoaded extends AgentState {
  final AgentSystem agentSys;
  final String activeThread;

  const AgentLoaded({required this.agentSys, required this.activeThread});
}

class AgentError extends AgentState {
  final String message;

  const AgentError({required this.message});
}

class AgentBloc extends Bloc<AgentEvent, AgentState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  AgentBloc({required this.client}) : super(const AgentInitial()) {
    on<LoadAgent>(_onLoad);
    on<SelectThread>(_onSelectThread);
    on<SendUserPrompt>(_onSend);
    on<UpdateAgent>(_onUpdate);
    on<LoadError>(_onError);
  }

  Future<void> _onLoad(LoadAgent event, Emitter<AgentState> emit) async {
    await _streamSubscription?.cancel();

    final table = client.from("agent_systems");
    final stream = table.stream(primaryKey: ["id"]);
    final filtered = stream.eq("id", event.id);
    final single = filtered.limit(1);

    _streamSubscription = single.listen(
      (rows) {
        final event = UpdateAgent(row: rows.first);
        add(event);
      },
      onError: (Object error) {
        final event = LoadError(message: error.toString());
        add(event);
      }
    );
  }

  void _onUpdate(UpdateAgent event, Emitter<AgentState> emit) {
    final agentSys = AgentSystem.fromJson(event.row);
    final newState = AgentLoaded(
      agentSys: agentSys,
      activeThread: state is AgentLoaded ? (state as AgentLoaded).activeThread : agentSys.agentIds[0]
    );
    emit(newState);
  }

  void _onSelectThread(SelectThread event, Emitter<AgentState> emit) {
    if (state is! AgentLoaded) return;

    final newState = AgentLoaded(
      agentSys: (state as AgentLoaded).agentSys,
      activeThread: event.agentId
    );
    emit(newState);
  }

  Future<void> _onSend(SendUserPrompt event, Emitter<AgentState> emit) async {
    if (state is! AgentLoaded) return;
    final agentSys = (state as AgentLoaded).agentSys;
    if (agentSys.status != AgentStatus.idle) {
      return;
    }

    final content = event.content.trim();
    if (content.isEmpty) {
      return;
    }

    try {
      final table = client.from("agent_systems");
      final update = table.update({
        "user_prompt": content,
        "status": AgentStatus.working.name
      });
      await update.eq("id", agentSys.id);
    } catch (error) {
      final newState = AgentError(message: error.toString());
      emit(newState);
    }
  }

  void _onError(LoadError event, Emitter<AgentState> emit) {
    final newState = AgentError(message: event.message);
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
