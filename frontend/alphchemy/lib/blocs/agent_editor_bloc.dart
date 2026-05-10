import "package:alphchemy/model/agent_system.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class AgentEditorEvent {
  const AgentEditorEvent();
}

class AddAgent extends AgentEditorEvent {
  final bool isSubagent;

  const AddAgent({required this.isSubagent});
}

class RemoveAgent extends AgentEditorEvent {
  final int index;
  final bool isSubagent;

  const RemoveAgent({required this.index, required this.isSubagent});
}

class UpdateAgentField extends AgentEditorEvent {
  final int index;
  final bool isSubagent;
  final String field;
  final Object value;

  const UpdateAgentField({
    required this.index,
    required this.isSubagent,
    required this.field,
    required this.value
  });
}

class AddModel extends AgentEditorEvent {
  final int index;
  final bool isSubagent;
  final String list;
  final String model;

  const AddModel({
    required this.index,
    required this.isSubagent,
    required this.list,
    required this.model
  });
}

class RemoveModel extends AgentEditorEvent {
  final int index;
  final bool isSubagent;
  final String list;
  final int modelIndex;

  const RemoveModel({
    required this.index,
    required this.isSubagent,
    required this.list,
    required this.modelIndex
  });
}

class AgentEditorState {
  final AgentSystemSchema schema;
  final int version;

  const AgentEditorState({required this.schema, this.version = 0});
}

class AgentEditorBloc extends Bloc<AgentEditorEvent, AgentEditorState> {
  AgentEditorBloc({Map<String, dynamic>? initialJson}) : super(_buildInitial(initialJson)) {
    on<AddAgent>(_onAddAgent);
    on<RemoveAgent>(_onRemoveAgent);
    on<UpdateAgentField>(_onUpdateField);
    on<AddModel>(_onAddModel);
    on<RemoveModel>(_onRemoveModel);
  }

  static AgentEditorState _buildInitial(Map<String, dynamic>? json) {
    if (json == null) {
      return AgentEditorState(schema: AgentSystemSchema.blank());
    }
    final schema = AgentSystemSchema.fromJson(json);
    return AgentEditorState(schema: schema);
  }

  Map<String, dynamic> exportToJson() {
    return state.schema.toJson();
  }

  void _onAddAgent(AddAgent event, Emitter<AgentEditorState> emit) {
    final blank = AgentConfig.blank();
    _modifyList(emit, event.isSubagent, (list) => [...list, blank]);
  }

  void _onRemoveAgent(RemoveAgent event, Emitter<AgentEditorState> emit) {
    _modifyList(emit, event.isSubagent, (list) {
      final newList = [...list];
      newList.removeAt(event.index);
      return newList;
    });
  }

  void _onUpdateField(UpdateAgentField event, Emitter<AgentEditorState> emit) {
    _modifyAgent(emit, event.isSubagent, event.index, (agent) {
      return _applyFieldUpdate(agent, event.field, event.value);
    });
  }

  static AgentConfig _applyFieldUpdate(AgentConfig agent, String field, Object value) {
    if (field == "id") {
      return agent.copyWith(id: value as String);
    }
    if (field == "maxContextLen") {
      return agent.copyWith(maxContextLen: value as int);
    }
    if (field == "nDelete") {
      return agent.copyWith(nDelete: value as int);
    }
    return agent;
  }

  void _onAddModel(AddModel event, Emitter<AgentEditorState> emit) {
    _modifyAgent(emit, event.isSubagent, event.index, (agent) {
      return _applyAddModel(agent, event.list, event.model);
    });
  }

  static AgentConfig _applyAddModel(AgentConfig agent, String list, String model) {
    if (list == "chat") {
      final newModels = [...agent.chatModels, model];
      return agent.copyWith(chatModels: newModels);
    }
    final newModels = [...agent.summarizeModels, model];
    return agent.copyWith(summarizeModels: newModels);
  }

  void _onRemoveModel(RemoveModel event, Emitter<AgentEditorState> emit) {
    _modifyAgent(emit, event.isSubagent, event.index, (agent) {
      return _applyRemoveModel(agent, event.list, event.modelIndex);
    });
  }

  static AgentConfig _applyRemoveModel(AgentConfig agent, String list, int modelIndex) {
    if (list == "chat") {
      final newModels = [...agent.chatModels];
      newModels.removeAt(modelIndex);
      return agent.copyWith(chatModels: newModels);
    }
    final newModels = [...agent.summarizeModels];
    newModels.removeAt(modelIndex);
    return agent.copyWith(summarizeModels: newModels);
  }

  void _modifyList(
    Emitter<AgentEditorState> emit,
    bool isSubagent,
    List<AgentConfig> Function(List<AgentConfig>) transform
  ) {
    final schema = state.schema;
    final source = isSubagent ? schema.subagentPool : schema.agents;
    final newList = transform(source);
    final newSchema = isSubagent
      ? AgentSystemSchema(agents: schema.agents, subagentPool: newList)
      : AgentSystemSchema(agents: newList, subagentPool: schema.subagentPool);
    _emitNew(emit, newSchema);
  }

  void _modifyAgent(
    Emitter<AgentEditorState> emit,
    bool isSubagent,
    int index,
    AgentConfig Function(AgentConfig) transform
  ) {
    _modifyList(emit, isSubagent, (list) {
      final newList = [...list];
      newList[index] = transform(newList[index]);
      return newList;
    });
  }

  void _emitNew(Emitter<AgentEditorState> emit, AgentSystemSchema schema) {
    final newState = AgentEditorState(schema: schema, version: state.version + 1);
    emit(newState);
  }
}
