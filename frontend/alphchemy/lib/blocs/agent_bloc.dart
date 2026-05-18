import "dart:async";

import "package:alphchemy/model/agent_system/agent_schema.dart";
import "package:alphchemy/model/agent_system/agent_system.dart";
import "package:alphchemy/model/agent_system/submission.dart";
import "package:alphchemy/model/experiment_summary.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

sealed class AgentEvent {
  const AgentEvent();
}

class SubscribeToAgent extends AgentEvent {
  final int id;

  const SubscribeToAgent({required this.id});
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

class DiscardSubmission extends AgentEvent {
  final int index;

  const DiscardSubmission({required this.index});
}

class QueueSubmissionExperiment extends AgentEvent {
  final int index;

  const QueueSubmissionExperiment({required this.index});
}

class DisplayAgentError extends AgentEvent {
  final String message;

  const DisplayAgentError({required this.message});
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
    on<SubscribeToAgent>(_onSubscribe);
    on<SelectThread>(_onSelectThread);
    on<SendUserPrompt>(_onSend);
    on<UpdateAgent>(_onUpdate);
    on<DiscardSubmission>(_onDiscard);
    on<QueueSubmissionExperiment>(_onQueue);
    on<DisplayAgentError>(_onError);
  }

  Future<void> _onSubscribe(SubscribeToAgent event, Emitter<AgentState> emit) async {
    await _streamSubscription?.cancel();
    emit(const AgentInitial());

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
        final event = DisplayAgentError(message: error.toString());
        add(event);
      }
    );
  }

  void _onUpdate(UpdateAgent event, Emitter<AgentState> emit) {
    late AgentSystem newAgentSys;
    late String newActiveThread;

    if (state is AgentLoaded) {
      final loaded = state as AgentLoaded;
      newAgentSys = loaded.agentSys.copyFromJson(event.row);
      newActiveThread = loaded.activeThread;
    } else {
      newAgentSys = AgentSystem.fromJson(event.row);
      newActiveThread = newAgentSys.agentIds[0];
    }

    final newState = AgentLoaded(agentSys: newAgentSys, activeThread: newActiveThread);
    emit(newState);
  }

  void _onSelectThread(SelectThread event, Emitter<AgentState> emit) {
    if (state is! AgentLoaded) {
      return;
    }

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

  Future<void> _onDiscard(DiscardSubmission event, Emitter<AgentState> emit) async {
    if (state is! AgentLoaded) {
      return;
    }
    final agentSys = (state as AgentLoaded).agentSys;

    try {
      await _deleteSubmission(agentSys, event.index);
    } catch (error) {
      final newState = AgentError(message: error.toString());
      emit(newState);
    }
  }

  Future<void> _onQueue(QueueSubmissionExperiment event, Emitter<AgentState> emit) async {
    if (state is! AgentLoaded) return;
    final agentSys = (state as AgentLoaded).agentSys;
    final submission = agentSys.submissions[event.index];
    if (submission is! ExperimentSubmission) {
      return;
    }

    try {
      final experimentsTable = client.from("experiments");
      await experimentsTable.insert({
        "title": submission.title,
        "experiment": submission.experimentJson,
        "status": ExperimentStatus.queued.name
      });
      await _deleteSubmission(agentSys, event.index);
    } catch (error) {
      final newState = AgentError(message: error.toString());
      emit(newState);
    }
  }

  Future<void> _deleteSubmission(AgentSystem agentSys, int idx) async {
    final submissionsJson = agentSys.submissions.map((submission) => submission.toJson()).toList();
    submissionsJson.removeAt(idx);

    final table = client.from("agent_systems");
    final update = table.update({"submissions": submissionsJson});
    await update.eq("id", agentSys.id);
  }

  void _onError(DisplayAgentError event, Emitter<AgentState> emit) {
    final newState = AgentError(message: event.message);
    emit(newState);
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
