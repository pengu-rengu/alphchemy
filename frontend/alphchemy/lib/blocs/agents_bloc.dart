import "dart:async";

import "package:alphchemy/model/agent.dart";
import "package:alphchemy/model/agent_status.dart";
import "package:alphchemy/model/agent_summary.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

typedef AgentsStreamFactory = Stream<List<Map<String, dynamic>>> Function();

sealed class AgentsEvent {
  const AgentsEvent();
}

class LoadAgents extends AgentsEvent {
  const LoadAgents();
}

class CreateAgent extends AgentsEvent {
  final String title;
  final Map<String, dynamic> schemaJson;

  const CreateAgent({required this.title, required this.schemaJson});
}

class DeleteAgent extends AgentsEvent {
  final int id;

  const DeleteAgent({required this.id});
}

class SelectAgent extends AgentsEvent {
  final int id;

  const SelectAgent({required this.id});
}

class SelectThread extends AgentsEvent {
  final String agentId;

  const SelectThread({required this.agentId});
}

class SendUserMessage extends AgentsEvent {
  final String content;

  const SendUserMessage({required this.content});
}

class ClearActive extends AgentsEvent {
  const ClearActive();
}

class _AgentsRowsChanged extends AgentsEvent {
  final List<Map<String, dynamic>> rows;

  const _AgentsRowsChanged({required this.rows});
}

class _AgentsFailed extends AgentsEvent {
  final String message;

  const _AgentsFailed({required this.message});
}

sealed class AgentsBlocState {
  const AgentsBlocState();
}

class AgentsInitial extends AgentsBlocState {
  const AgentsInitial();
}

class AgentsLoaded extends AgentsBlocState {
  final Map<int, Agent> store;
  final int? activeSystemId;
  final String? activeThreadId;
  final bool sending;
  final String? errorMessage;

  const AgentsLoaded({
    required this.store,
    this.activeSystemId,
    this.activeThreadId,
    this.sending = false,
    this.errorMessage
  });

  List<AgentSummary> get summaries {
    final mapped = store.values.map((data) => data.summary);
    final list = mapped.toList();
    list.sort((summary1, summary2) => summary2.lastEdited.compareTo(summary1.lastEdited));
    return list;
  }

  Agent? get activeData {
    final id = activeSystemId;
    if (id == null) return null;
    return store[id];
  }
}

class AgentsBloc extends Bloc<AgentsEvent, AgentsBlocState> {
  final SupabaseClient client;
  final AgentsStreamFactory? _streamFactory;
  final Map<int, Agent> _store = {};
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  AgentsBloc({
    required this.client,
    AgentsStreamFactory? streamFactory
  })  : _streamFactory = streamFactory,
        super(const AgentsInitial()) {
    on<LoadAgents>(_onLoad);
    on<CreateAgent>(_onCreate);
    on<DeleteAgent>(_onDelete);
    on<SelectAgent>(_onSelect);
    on<SelectThread>(_onSelectThread);
    on<SendUserMessage>(_onSend);
    on<ClearActive>(_onClear);
    on<_AgentsRowsChanged>(_onRowsChanged);
    on<_AgentsFailed>(_onFailed);
  }

  Future<void> _onLoad(LoadAgents event, Emitter<AgentsBlocState> emit) async {
    await _streamSubscription?.cancel();
    final stream = _agentStream();
    _streamSubscription = stream.listen(
      (rows) => add(_AgentsRowsChanged(rows: rows)),
      onError: (Object error) => add(_AgentsFailed(message: error.toString()))
    );
    emit(_buildLoaded());
  }

  Future<void> _onCreate(CreateAgent event, Emitter<AgentsBlocState> emit) async {
    try {
      final agent = await _insertAgent(
        title: event.title,
        schemaJson: event.schemaJson
      );
      _store[agent.id] = agent;
      final threadId = _firstThreadId(agent);
      final newState = _buildLoaded(
        activeSystemId: agent.id,
        activeThreadId: threadId
      );
      emit(newState);
    } catch (error) {
      emit(_buildLoaded(errorMessage: error.toString()));
    }
  }

  Future<void> _onDelete(DeleteAgent event, Emitter<AgentsBlocState> emit) async {
    try {
      await _deleteAgent(event.id);
      _store.remove(event.id);
      emit(_buildLoaded());
    } catch (error) {
      emit(_buildLoaded(errorMessage: error.toString()));
    }
  }

  void _onSelect(SelectAgent event, Emitter<AgentsBlocState> emit) {
    final data = _store[event.id];
    if (data == null) return;
    final threadId = _firstThreadId(data);
    final newState = _buildLoaded(
      activeSystemId: event.id,
      activeThreadId: threadId
    );
    emit(newState);
  }

  void _onSelectThread(SelectThread event, Emitter<AgentsBlocState> emit) {
    final current = _currentLoaded();
    if (current == null) return;
    final data = current.activeData;
    if (data == null) return;
    final threadIds = _threadIds(data);
    if (!threadIds.contains(event.agentId)) return;
    final newState = AgentsLoaded(
      store: current.store,
      activeSystemId: current.activeSystemId,
      activeThreadId: event.agentId,
      sending: current.sending
    );
    emit(newState);
  }

  Future<void> _onSend(SendUserMessage event, Emitter<AgentsBlocState> emit) async {
    final current = _currentLoaded();
    if (current == null) return;
    if (current.sending) return;

    final activeId = current.activeSystemId;
    if (activeId == null) return;
    final data = _store[activeId];
    if (data == null) return;
    if (!_canSendPrompt(data)) return;

    final content = event.content.trim();
    if (content.isEmpty) return;

    final sendingState = AgentsLoaded(
      store: current.store,
      activeSystemId: current.activeSystemId,
      activeThreadId: current.activeThreadId,
      sending: true
    );
    emit(sendingState);

    try {
      await _writePrompt(activeId, content);
      _store[activeId] = data.copyWith(userPrompt: content);
      emit(_buildLoaded(sending: false));
    } catch (error) {
      emit(_buildLoaded(sending: false, errorMessage: error.toString()));
    }
  }

  void _onClear(ClearActive event, Emitter<AgentsBlocState> emit) {
    final newState = AgentsLoaded(store: Map<int, Agent>.from(_store));
    emit(newState);
  }

  void _onRowsChanged(_AgentsRowsChanged event, Emitter<AgentsBlocState> emit) {
    _store.clear();
    for (final row in event.rows) {
      final agent = Agent.fromJson(row);
      _store[agent.id] = agent;
    }
    emit(_buildLoaded());
  }

  void _onFailed(_AgentsFailed event, Emitter<AgentsBlocState> emit) {
    emit(_buildLoaded(errorMessage: event.message));
  }

  Stream<List<Map<String, dynamic>>> _agentStream() {
    final factory = _streamFactory;
    if (factory != null) {
      return factory();
    }

    final table = client.from("agents");
    final stream = table.stream(primaryKey: ["id"]);
    return stream.order("last_edited", ascending: false);
  }

  Future<Agent> _insertAgent({
    required String title,
    required Map<String, dynamic> schemaJson
  }) async {
    final payload = <String, dynamic>{
      "title": _cleanTitle(title),
      "schema": schemaJson,
      "status": AgentStatus.created.label,
      "state": null,
      "user_prompt": null
    };
    final table = client.from("agents");
    final insert = table.insert(payload);
    final query = insert.select("id,last_edited,title,schema,state,status,user_prompt");
    final row = await query.single();
    final json = Map<String, dynamic>.from(row);
    return Agent.fromJson(json);
  }

  Future<void> _deleteAgent(int id) async {
    final table = client.from("agents");
    final delete = table.delete();
    final filtered = delete.eq("id", id);
    await filtered;
  }

  Future<void> _writePrompt(int id, String prompt) async {
    final table = client.from("agents");
    final update = table.update({"user_prompt": prompt});
    final filtered = update.eq("id", id);
    await filtered;
  }

  AgentsLoaded? _currentLoaded() {
    final current = state;
    if (current is AgentsLoaded) return current;
    return null;
  }

  AgentsLoaded _buildLoaded({
    int? activeSystemId,
    String? activeThreadId,
    bool? sending,
    String? errorMessage
  }) {
    final current = _currentLoaded();
    final rawActiveId = activeSystemId ?? current?.activeSystemId;
    final nextActiveId = _store.containsKey(rawActiveId) ? rawActiveId : null;
    final activeData = nextActiveId == null ? null : _store[nextActiveId];
    final rawThreadId = activeThreadId ?? current?.activeThreadId;
    final nextThreadId = _normalizeThreadId(activeData, rawThreadId);

    return AgentsLoaded(
      store: Map<int, Agent>.from(_store),
      activeSystemId: nextActiveId,
      activeThreadId: nextThreadId,
      sending: sending ?? current?.sending ?? false,
      errorMessage: errorMessage
    );
  }

  static String? _normalizeThreadId(Agent? data, String? threadId) {
    if (data == null) return null;
    final ids = _threadIds(data);
    if (threadId != null && ids.contains(threadId)) {
      return threadId;
    }
    if (ids.isEmpty) return null;
    return ids.first;
  }

  static String? _firstThreadId(Agent data) {
    final ids = _threadIds(data);
    if (ids.isEmpty) return null;
    return ids.first;
  }

  static List<String> _threadIds(Agent data) {
    final stateOrder = data.state?.agentOrder ?? const [];
    if (stateOrder.isNotEmpty) {
      return stateOrder;
    }

    final mapped = data.schema.agents.map((agent) => agent.id);
    return mapped.toList();
  }

  static bool _canSendPrompt(Agent data) {
    if (data.status != AgentStatus.idle) {
      return false;
    }
    return data.userPrompt == null;
  }

  static String _cleanTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return "Untitled Agent";
    }

    return trimmed;
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    return super.close();
  }
}
