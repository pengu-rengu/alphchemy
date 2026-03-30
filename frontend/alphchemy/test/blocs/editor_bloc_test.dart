import "dart:ui";

import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/objects/mock_data.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

void main() {
  group("EditorBloc ordering", () {
    test("editing a parameter keeps its position in the list", () async {
      final bloc = EditorBloc();
      addTearDown(() async {
        await bloc.close();
      });

      await _loadParams(bloc);

      bloc.add(UpdateParam(
        oldName: "second",
        param: Param(
          name: "second",
          type: ParamType.floatType,
          values: [4.0]
        )
      ));
      await _waitForState(bloc);

      expect(bloc.state.params.keys.toList(), ["first", "second", "third"]);
    });

    test("renaming a parameter keeps its position in the list", () async {
      final bloc = EditorBloc();
      addTearDown(() async {
        await bloc.close();
      });

      await _loadParams(bloc);

      bloc.add(UpdateParam(
        oldName: "second",
        param: Param(
          name: "renamed",
          type: ParamType.floatType,
          values: [2.0]
        )
      ));
      await _waitForState(bloc);

      expect(bloc.state.params.keys.toList(), ["first", "renamed", "third"]);
    });
  });

  test("load graph initializes params and export preserves shape", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: mockWrapperJson));
    await _waitForState(bloc);

    expect(bloc.state, isA<EditorLoaded>());
    expect(bloc.state.params.keys.toList(), [
      "mut_rate",
      "pop_size",
      "default_value"
    ]);

    final export = bloc.exportToJson();
    final generator = export["generator"] as Map<String, dynamic>;
    expect(export["param_space"], mockWrapperJson["param_space"]);
    expect(generator["title"], "Experiment");
    expect(generator["val_size"], 0.2);
    expect(generator["test_size"], 0.1);
    expect(generator["cv_folds"], 3);
    expect(generator["fold_size"], 0.3);
    expect(generator["strategy"], isA<Map<String, dynamic>>());
  });

  test("adding a node uses the snapped viewport center", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: mockWrapperJson));
    await _waitForState(bloc);

    final controller = _loadedController(bloc);
    controller.setScreenSize(Size(800, 600));
    controller.setViewport(GraphViewport(x: 100, y: -50, zoom: 2.0));

    final expectedPosition = controller.snapToGrid(
      controller.getViewportCenter().offset
    );

    bloc.add(AddNode(nodeType: "constant_feature"));
    await _flushEventQueue();

    final nodes = controller.getNodesByType("constant_feature");
    expect(nodes, hasLength(1));
    expect(nodes.single.position.value, expectedPosition);
  });

  test("adding a node falls back to origin when screen size is unset", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: mockWrapperJson));
    await _waitForState(bloc);

    final controller = _loadedController(bloc);

    bloc.add(AddNode(nodeType: "constant_feature"));
    await _flushEventQueue();

    final nodes = controller.getNodesByType("constant_feature");
    expect(nodes, hasLength(1));
    expect(nodes.single.position.value, Offset.zero);
  });
}

Future<void> _loadParams(EditorBloc bloc) async {
  bloc.add(AddParam(
    param: Param(
      name: "first",
      type: ParamType.intType,
      values: [1]
    )
  ));
  await _waitForState(bloc);

  bloc.add(AddParam(
    param: Param(
      name: "second",
      type: ParamType.floatType,
      values: [2.0]
    )
  ));
  await _waitForState(bloc);

  bloc.add(AddParam(
    param: Param(
      name: "third",
      type: ParamType.stringType,
      values: ["3"]
    )
  ));
  await _waitForState(bloc);
}

Future<void> _waitForState(EditorBloc bloc) async {
  await bloc.stream.first;
}

NodeFlowController<NodeObject, void> _loadedController(EditorBloc bloc) {
  final state = bloc.state;
  expect(state, isA<EditorLoaded>());
  return (state as EditorLoaded).controller;
}

Future<void> _flushEventQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
