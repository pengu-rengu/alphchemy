import "package:alphchemy/model/agent_system/agent_schema.dart";
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

class AddChatModel extends AgentEditorEvent {
  final int idx;
  final bool isSubagent;
  final String model;

  const AddChatModel({required this.idx, required this.isSubagent, required this.model});
}

class DeleteChatModel extends AgentEditorEvent {
  final int idx;
  final bool isSubagent;
  final int modelIdx;

  const DeleteChatModel({required this.idx, required this.isSubagent, required this.modelIdx});
}

class AddSummarizeModel extends AgentEditorEvent {
  final int idx;
  final bool isSubagent;
  final String model;

  const AddSummarizeModel({required this.idx, required this.isSubagent, required this.model});
}

class DeleteSummarizeModel extends AgentEditorEvent {
  final int idx;
  final bool isSubagent;
  final int modelIdx;

  const DeleteSummarizeModel({required this.idx, required this.isSubagent, required this.modelIdx});
}

class AgentEditorState {
  final AgentSystemSchema schema;
  final int version;

  const AgentEditorState({required this.schema, this.version = 0});
}

class AgentEditorBloc extends Bloc<AgentEditorEvent, AgentSystemSchema> {
  AgentEditorBloc({Map<String, dynamic>? initialJson}) : super(_buildInitial(initialJson)) {
    on<AddAgent>(_onAddAgent);
    on<RemoveAgent>(_onRemoveAgent);
    on<UpdateAgentField>(_onUpdateField);
    on<AddChatModel>(_onAddChatModel);
    on<DeleteChatModel>(_onDeleteChatModel);
    on<AddSummarizeModel>(_onAddSummarizeModel);
    on<DeleteSummarizeModel>(_onDeleteSummarizeModel);
  }

  static AgentSystemSchema _buildInitial(Map<String, dynamic>? json) {
    if (json == null) {
      return AgentSystemSchema.blank();
    } else {
      return AgentSystemSchema.fromJson(json);
    }
  }

  void _onAddAgent(AddAgent event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agents = _getAgents(newState, event.isSubagent);

    final newAgent = AgentConfig.blank();
    agents.add(newAgent);

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
    }
    
    emit(newState);
  }

  void _onAddChatModel(AddChatModel event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agent = _getAgent(newState, event.idx, event.isSubagent);

    agent.chatModels.add(event.model);

    emit(newState);
  }
  
  void _onDeleteChatModel(DeleteChatModel event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agent = _getAgent(newState, event.idx, event.isSubagent);

    agent.chatModels.removeAt(event.modelIdx);

    emit(newState);
  }

  void _onAddSummarizeModel(AddSummarizeModel event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agent = _getAgent(newState, event.idx, event.isSubagent);

    agent.summarizeModels.add(event.model);

    emit(newState);
  }

  void _onDeleteSummarizeModel(DeleteSummarizeModel event, Emitter<AgentSystemSchema> emit) {
    final newState = state.copy();
    final agent = _getAgent(newState, event.idx, event.isSubagent);

    agent.summarizeModels.removeAt(event.modelIdx);

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
