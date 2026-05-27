import "dart:async";

import "package:alphchemy/model/agents/agent_schema.dart";
import "package:alphchemy/model/agents/agent_summary.dart";
import "package:alphchemy/utils.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class AgentsEvent {
  const AgentsEvent();
}

class SubscribeToAgents extends AgentsEvent {
  const SubscribeToAgents();
}

class CreateAgent extends AgentsEvent {
  final String title;
  final AgentSystemSchema schema;

  const CreateAgent({required this.title, required this.schema});
}

class DeleteAgent extends AgentsEvent {
  final int agentSysId;

  const DeleteAgent({required this.agentSysId});
}

class SelectAgent extends AgentsEvent {
  final int agentSysId;

  const SelectAgent({required this.agentSysId});
}

class UpdateSummaries extends AgentsEvent {
  const UpdateSummaries();
}

class ShowAgentsError extends AgentsEvent {
  final String message;

  const ShowAgentsError({required this.message});
}

sealed class AgentsState {
  const AgentsState();
}

class AgentsInitial extends AgentsState {
  const AgentsInitial();
}

class AgentsLoaded extends AgentsState {
  final List<AgentSummary> summaries;
  final int? activeId;

  const AgentsLoaded({required this.summaries, required this.activeId});
}

class AgentsError extends AgentsState {
  final String message;

  const AgentsError({required this.message});
}

class AgentsBloc extends Bloc<AgentsEvent, AgentsState> {
  final SupabaseClient client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  AgentsBloc({required this.client}) : super(const AgentsInitial()) {
    on<SubscribeToAgents>(_onSubscribe);
    on<UpdateSummaries>(_onUpdate);
    on<CreateAgent>(_onCreate);
    on<DeleteAgent>(_onDelete);
    on<SelectAgent>(_onSelect);
    on<ShowAgentsError>(_onError);
  }

  Future<void> _onSubscribe(SubscribeToAgents event, Emitter<AgentsState> emit) async {
    await _streamSubscription?.cancel();
    final table = client.from("agent_systems");
    final stream = table.stream(primaryKey: ["id"]);
    _streamSubscription = stream.listen(
      (rows) {
        const event = UpdateSummaries();
        add(event);
      },
      onError: (error) {
        final event = ShowAgentsError(message: error.toString());
        add(event);
      }
    );
  }

  Future<void> _onUpdate(UpdateSummaries event, Emitter<AgentsState> emit) async {
    try {
      final query = client.from("agent_systems").select();
      final rows = await query.order("last_edited");
      final summaries = rows.map(AgentSummary.fromJson).toList();

      final prevActiveId = state is AgentsLoaded ? (state as AgentsLoaded).activeId : null;
      final newActiveId = summaries.any((summary) => summary.id == prevActiveId) ? prevActiveId : null;

      final newState = AgentsLoaded(summaries: summaries, activeId: newActiveId);
      emit(newState);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onCreate(CreateAgent event, Emitter<AgentsState> emit) async {
    try {
      final title = cleanTitle(event.title);

      final table = client.from("agent_systems");
      await table.insert({
        "title": title,
        "schema": event.schema.toJson(),
        "status": AgentStatus.created.name,
        "state": null,
        "user_prompt": null
      });
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  Future<void> _onDelete(DeleteAgent event, Emitter<AgentsState> emit) async {
    try {
      final table = client.from("agent_systems");
      await table.delete().eq("id", event.agentSysId);
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onSelect(SelectAgent event, Emitter<AgentsState> emit) {
    final newState = AgentsLoaded(
      summaries: (state as AgentsLoaded).summaries,
      activeId: event.agentSysId
    );
    emit(newState);
  }

  void _onError(ShowAgentsError event, Emitter<AgentsState> emit) {
    _emitError(emit: emit, error: event.message);
  }

  void _emitError({required Emitter<AgentsState> emit, required Object error}) {
    final newState = AgentsError(message: error.toString());
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
