import "dart:async";

import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/agent_summary.dart";
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
  final Map<String, dynamic> schemaJson;

  const CreateAgent({required this.title, required this.schemaJson});
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
  final List<Map<String, dynamic>> rows;

  const UpdateSummaries({required this.rows});
}

class DisplayError extends AgentsEvent {
  final String message;

  const DisplayError({required this.message});
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

  const AgentsLoaded({required this.summaries, this.activeId});
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
    on<DisplayError>(_onError);
  }

  Future<void> _onSubscribe(SubscribeToAgents event, Emitter<AgentsState> emit) async {
    await _streamSubscription?.cancel();
    final table = client.from("agent_systems");
    final stream = table.stream(primaryKey: ["id"]);
    _streamSubscription = stream.listen(
      (rows) {
        final event = UpdateSummaries(rows: rows);
        add(event);
      },
      onError: (error) {
        final event = DisplayError(message: error.toString());
        add(event);
      }
    );
  }

  void _onUpdate(UpdateSummaries event, Emitter<AgentsState> emit) {
    AgentSummary summaryFromJson(Map<String, dynamic> json) => AgentSummary.fromJson(json);
    final summaries = event.rows.map(summaryFromJson).toList();
    int compareSummaries(summary1, summary2) => summary1.lastEdited.compareTo(summary2.lastEdited);
    summaries.sort(compareSummaries);

    final newState = AgentsLoaded(
      summaries: summaries,
      activeId: state is AgentsLoaded ? (state as AgentsLoaded).activeId : null
    );
    emit(newState);
  }

  Future<void> _onCreate(CreateAgent event, Emitter<AgentsState> emit) async {
    try {
      final table = client.from("agent_systems");
      await table.insert({
        "title": cleanAgentTitle(event.title),
        "schema": event.schemaJson,
        "status": AgentStatus.created.name,
        "state": null,
        "user_prompt": null
      });
    } catch (error) {
      final newState = AgentsError(message: error.toString());
      emit(newState);
    }
  }

  Future<void> _onDelete(DeleteAgent event, Emitter<AgentsState> emit) async {
    try {
      final table = client.from("agent_systems");
      await table.delete().eq("id", event.agentSysId);
    } catch (error) {
      final newState = AgentsError(message: error.toString());
      emit(newState);
    }
  }

  void _onSelect(SelectAgent event, Emitter<AgentsState> emit) {
    final newState = AgentsLoaded(
      summaries: (state as AgentsLoaded).summaries,
      activeId: event.agentSysId
    );
    emit(newState);
  }

  void _onError(DisplayError event, Emitter<AgentsState> emit) {
    final newState = AgentsError(message: event.message);
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
