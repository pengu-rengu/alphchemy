import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:flutter_test/flutter_test.dart";

import "../helpers/supabase_test_server.dart";

void main() {
  test("loads experiments from Supabase", () async {
    final response = SupabaseTestResponse(body: [
      _experimentJson(id: 1, title: "First Experiment", status: "completed"),
      _experimentJson(
        id: 2,
        title: "Broken Experiment",
        status: "errored",
        errorMessage: "cv_folds must be greater than zero"
      )
    ]);
    final server = await SupabaseTestServer.start([response]);
    final client = server.createClient();
    final bloc = ExperimentsBloc(client: client);
    addTearDown(bloc.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final loadedFuture = bloc.stream.firstWhere(_ExperimentsBlocMatchers.isLoaded);
    bloc.add(const LoadExperiments());

    final loadedState = await loadedFuture as ExperimentsLoaded;
    final request = server.requests.first;

    expect(request.method, "GET");
    expect(request.path, "/rest/v1/experiments");
    expect(request.query["select"], "id,created_at,title,status,results");
    expect(loadedState.experiments.length, 2);
    expect(loadedState.experiments.first.title, "First Experiment");
    expect(loadedState.experiments.first.status.label, "completed");
    expect(loadedState.experiments.last.errorMessage, "cv_folds must be greater than zero");
  });

  test("queues and deletes experiments through Supabase", () async {
    final insertResponse = SupabaseTestResponse(
      body: _experimentJson(id: 1, title: "Queued Experiment")
    );
    final queuedResponse = SupabaseTestResponse(body: [
      _experimentJson(id: 1, title: "Queued Experiment")
    ]);
    const deleteResponse = SupabaseTestResponse(body: <Object>[]);
    const emptyResponse = SupabaseTestResponse(body: <Object>[]);
    final server = await SupabaseTestServer.start([
      insertResponse,
      queuedResponse,
      deleteResponse,
      emptyResponse
    ]);
    final client = server.createClient();
    final bloc = ExperimentsBloc(client: client);
    addTearDown(bloc.close);
    addTearDown(client.dispose);
    addTearDown(server.close);

    final queuedFuture = bloc.stream.firstWhere(_ExperimentsBlocMatchers.hasOneExperiment);
    final data = <String, dynamic>{
      "title": "Draft Title",
      "settings": {
        "symbol": "SPY"
      }
    };
    final queueEvent = QueueExperiment(
      title: " Queued Experiment ",
      data: data
    );
    bloc.add(queueEvent);

    final queuedState = await queuedFuture as ExperimentsLoaded;
    final insertRequest = server.requests[0];
    final insertBody = insertRequest.body as Map<String, dynamic>;
    final experiment = insertBody["experiment"] as Map<String, dynamic>;

    expect(queuedState.experiments.first.title, "Queued Experiment");
    expect(insertRequest.method, "POST");
    expect(insertRequest.path, "/rest/v1/experiments");
    expect(insertBody["title"], "Queued Experiment");
    expect(insertBody["status"], "queued");
    expect(experiment.containsKey("title"), false);

    final deleteFuture = bloc.stream.firstWhere(_ExperimentsBlocMatchers.isEmptyLoaded);
    bloc.add(const DeleteExperiment(id: 1));

    final deleteState = await deleteFuture as ExperimentsLoaded;
    final deleteRequest = server.requests[2];

    expect(deleteState.experiments, isEmpty);
    expect(deleteRequest.method, "DELETE");
    expect(deleteRequest.path, "/rest/v1/experiments");
    expect(deleteRequest.query["id"], "eq.1");
  });
}

class _ExperimentsBlocMatchers {
  const _ExperimentsBlocMatchers();

  static bool isLoaded(ExperimentsState state) {
    return state is ExperimentsLoaded;
  }

  static bool hasOneExperiment(ExperimentsState state) {
    if (state is! ExperimentsLoaded) {
      return false;
    }

    return state.experiments.length == 1;
  }

  static bool isEmptyLoaded(ExperimentsState state) {
    if (state is! ExperimentsLoaded) {
      return false;
    }

    return state.experiments.isEmpty;
  }
}

Map<String, dynamic> _experimentJson({
  required int id,
  required String title,
  String status = "queued",
  String? errorMessage
}) {
  final results = errorMessage == null
      ? null
      : {
          "error": errorMessage,
          "is_internal": false
        };

  return {
    "id": id,
    "created_at": "2026-05-09T12:00:00Z",
    "title": title,
    "status": status,
    "results": results
  };
}
