import "dart:async";

import "package:alphchemy/blocs/agents_bloc.dart";
import "package:flutter_test/flutter_test.dart";

import "../helpers/supabase_test_server.dart";

void main() {
  test("loads agents from realtime stream rows", () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final server = await SupabaseTestServer.start(const []);
    final client = server.createClient();
    final bloc = AgentsBloc(
      client: client,
      streamFactory: () => controller.stream
    );
    addTearDown(bloc.close);
    addTearDown(controller.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final loadedFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.hasOneAgent);
    bloc.add(const LoadAgents());
    controller.add([_agentRow(id: 1, title: "Stream Agent", status: "idle", state: _stateJson())]);

    final loadedState = await loadedFuture as AgentsLoaded;

    expect(loadedState.summaries.first.id, 1);
    expect(loadedState.summaries.first.title, "Stream Agent");
  });

  test("creates agent rows with schema and created status", () async {
    final insertResponse = SupabaseTestResponse(
      body: _agentRow(id: 3, title: "Created Agent")
    );
    final server = await SupabaseTestServer.start([insertResponse]);
    final client = server.createClient();
    final bloc = AgentsBloc(client: client);
    addTearDown(bloc.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final createdFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.hasOneAgent);
    final event = CreateAgent(
      title: " Created Agent ",
      schemaJson: _schemaJson()
    );
    bloc.add(event);

    final loadedState = await createdFuture as AgentsLoaded;
    final request = server.requests.first;
    final body = request.body as Map<String, dynamic>;

    expect(loadedState.activeSystemId, 3);
    expect(request.method, "POST");
    expect(request.path, "/rest/v1/agents");
    expect(body["title"], "Created Agent");
    expect(body["status"], "created");
    expect(body["schema"], _schemaJson());
    expect(body["state"], isNull);
    expect(body["user_prompt"], isNull);
    expect(body.containsKey("id"), false);
  });

  test("deletes agent rows through Supabase", () async {
    const deleteResponse = SupabaseTestResponse(body: <Object>[]);
    final controller = StreamController<List<Map<String, dynamic>>>();
    final server = await SupabaseTestServer.start([deleteResponse]);
    final client = server.createClient();
    final bloc = AgentsBloc(
      client: client,
      streamFactory: () => controller.stream
    );
    addTearDown(bloc.close);
    addTearDown(controller.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final loadedFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.hasOneAgent);
    bloc.add(const LoadAgents());
    controller.add([_agentRow(id: 4, title: "Delete Agent", status: "idle", state: _stateJson())]);
    await loadedFuture;

    final emptyFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.isEmptyLoaded);
    bloc.add(const DeleteAgent(id: 4));

    await emptyFuture;
    final request = server.requests.first;

    expect(request.method, "DELETE");
    expect(request.path, "/rest/v1/agents");
    expect(request.query["id"], "eq.4");
  });

  test("writes user prompt without changing status", () async {
    const updateResponse = SupabaseTestResponse(body: <Object>[]);
    final controller = StreamController<List<Map<String, dynamic>>>();
    final server = await SupabaseTestServer.start([updateResponse]);
    final client = server.createClient();
    final bloc = AgentsBloc(
      client: client,
      streamFactory: () => controller.stream
    );
    addTearDown(bloc.close);
    addTearDown(controller.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final loadedFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.hasOneAgent);
    bloc.add(const LoadAgents());
    controller.add([_agentRow(id: 5, title: "Idle Agent", status: "idle", state: _stateJson())]);
    await loadedFuture;
    bloc.add(const SelectAgent(id: 5));

    final promptFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.hasPendingPrompt);
    bloc.add(const SendUserMessage(content: " Find a breakout "));

    final loadedState = await promptFuture as AgentsLoaded;
    final request = server.requests.first;
    final body = request.body as Map<String, dynamic>;

    expect(loadedState.activeData?.userPrompt, "Find a breakout");
    expect(request.method, "PATCH");
    expect(request.path, "/rest/v1/agents");
    expect(request.query["id"], "eq.5");
    expect(body["user_prompt"], "Find a breakout");
    expect(body.containsKey("status"), false);
  });

  test("does not send prompts for working or pending agents", () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final server = await SupabaseTestServer.start(const []);
    final client = server.createClient();
    final bloc = AgentsBloc(
      client: client,
      streamFactory: () => controller.stream
    );
    addTearDown(bloc.close);
    addTearDown(controller.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final loadedFuture = bloc.stream.firstWhere(_AgentsBlocMatchers.hasTwoAgents);
    bloc.add(const LoadAgents());
    controller.add([
      _agentRow(id: 6, title: "Working Agent", status: "working", state: _stateJson()),
      _agentRow(id: 7, title: "Pending Agent", status: "idle", state: _stateJson(), userPrompt: "queued")
    ]);
    await loadedFuture;

    bloc.add(const SelectAgent(id: 6));
    bloc.add(const SendUserMessage(content: "blocked"));
    bloc.add(const SelectAgent(id: 7));
    bloc.add(const SendUserMessage(content: "also blocked"));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(server.requests, isEmpty);
  });
}

class _AgentsBlocMatchers {
  const _AgentsBlocMatchers();

  static bool hasOneAgent(AgentsBlocState state) {
    if (state is! AgentsLoaded) {
      return false;
    }

    return state.store.length == 1;
  }

  static bool hasTwoAgents(AgentsBlocState state) {
    if (state is! AgentsLoaded) {
      return false;
    }

    return state.store.length == 2;
  }

  static bool isEmptyLoaded(AgentsBlocState state) {
    if (state is! AgentsLoaded) {
      return false;
    }

    return state.store.isEmpty;
  }

  static bool hasPendingPrompt(AgentsBlocState state) {
    if (state is! AgentsLoaded) {
      return false;
    }

    return state.activeData?.userPrompt == "Find a breakout";
  }
}

Map<String, dynamic> _agentRow({
  required int id,
  required String title,
  String status = "created",
  Map<String, dynamic>? state,
  String? userPrompt
}) {
  return {
    "id": id,
    "last_edited": "2026-05-10T14:00:00Z",
    "title": title,
    "schema": _schemaJson(),
    "state": state,
    "status": status,
    "user_prompt": userPrompt
  };
}

Map<String, dynamic> _schemaJson() {
  return {
    "agents": [
      {
        "id": "Alpha",
        "max_context_len": 15,
        "n_delete": 5,
        "chat_models": ["deepseek/deepseek-v3.2"],
        "summarize_models": ["deepseek/deepseek-v3.2"]
      }
    ],
    "subagent_pool": []
  };
}

Map<String, dynamic> _stateJson() {
  return {
    "user_prompt": "",
    "system_prompts": {
      "Alpha": ""
    },
    "summaries": {
      "Alpha": ""
    },
    "agent_contexts": {
      "Alpha": [
        {
          "role": "user",
          "personal_output": "[USER] hello",
          "global_output": ""
        }
      ]
    },
    "commands": [],
    "params": [],
    "proposal_state": {
      "state": "idle"
    },
    "agent_order": ["Alpha"],
    "turn": 0,
    "is_subagent": false
  };
}
