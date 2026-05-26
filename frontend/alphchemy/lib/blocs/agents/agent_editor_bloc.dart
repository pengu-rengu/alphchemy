import "package:alphchemy/model/agents/agent_schema.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class AgentEditorEvent {
  const AgentEditorEvent();
}

class AddAgent extends AgentEditorEvent {
  final bool isSubagent;

  const AddAgent({required this.isSubagent});
}

class RemoveAgent extends AgentEditorEvent {
  final int idx;
  final bool isSubagent;

  const RemoveAgent({required this.idx, required this.isSubagent});
}

class UpdateAgentField extends AgentEditorEvent {
  final int idx;
  final bool isSubagent;
  final String field;
  final dynamic value;

  const UpdateAgentField({required this.idx, required this.isSubagent, required this.field, required this.value});
}

class AgentEditorBloc extends Bloc<AgentEditorEvent, AgentSystemSchema> {
  AgentEditorBloc({AgentSystemSchema? schema}) : super(_init(schema)) {
    on<AddAgent>(_onAddAgent);
    on<RemoveAgent>(_onRemoveAgent);
    on<UpdateAgentField>(_onUpdateField);
  }

  static AgentSystemSchema _init(AgentSystemSchema? schema) {
    if (schema == null) {
      return const AgentSystemSchema();
    } else {
      return schema;
    }
  }

  void _onAddAgent(AddAgent event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agents = _getAgents(newState, event.isSubagent);

    agents.add(AgentConfig());

    emit(newState);
  }

  void _onRemoveAgent(RemoveAgent event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agents = _getAgents(newState, event.isSubagent);

    agents.removeAt(event.idx);

    emit(newState);
  }

  void _onUpdateField(UpdateAgentField event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agent = _getAgent(newState, event.idx, event.isSubagent);

    final value = event.value;
    switch (event.field) {
      case "id":
        agent.id = value;
        break;
      case "maxContextLen":
        agent.maxContextLen = value;
        break;
      case "nDelete":
        agent.nDelete = value;
        break;
      case "chatModel":
        agent.chatModel = value;
        break;
      case "chatFallbackModel":
        agent.chatFallbackModel = value;
        break;
      case "summarizeModel":
        agent.summarizeModel = value;
        break;
      case "summarizeFallbackModel":
        agent.summarizeFallbackModel = value;
        break;
      case "additionalInstructions":
        agent.additionalInstructions = value;
        break;
    }

    emit(newState);
  }

  List<AgentConfig> _getAgents(AgentSystemSchema newState, bool isSubagent) {
    if (isSubagent) {
      return newState.subagentPool;
    }
    return newState.agents;
  }

  AgentConfig _getAgent(AgentSystemSchema newState, int idx, bool isSubagent) {
    if (isSubagent) {
      return newState.subagentPool[idx];
    }
    return newState.agents[idx];
  }
}
