import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/generator/features.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_sidebar.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class TestEditorBloc extends EditorBloc {
  TestEditorBloc({required ParamSpace paramSpace}) : super() {
    final controller = NodeFlowController<NodeObject, void>(
      nodes: const [],
      connections: const []
    );
    emit(EditorLoaded(controller: controller, paramSpace: paramSpace));
  }
}

Node<NodeObject> buildNode(NodeObject data) {
  return Node<NodeObject>(
    id: "node_1",
    type: data.nodeType.value,
    position: Offset.zero,
    data: data,
    ports: const [],
    size: const Size(250, 0)
  );
}

Widget buildTestApp({
  required EditorBloc editorBloc,
  required NodeDataBloc nodeDataBloc,
  required Widget child
}) {
  return MaterialApp(
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<EditorBloc>.value(value: editorBloc),
          BlocProvider<NodeDataBloc>.value(value: nodeDataBloc)
        ],
        child: Material(child: child)
      )
    )
  );
}

Widget buildEditorOnlyApp({
  required EditorBloc editorBloc,
  required Widget child
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<EditorBloc>.value(
        value: editorBloc,
        child: Material(child: child)
      )
    )
  );
}

Future<void> selectDropdownItem(WidgetTester tester, Key key, String label) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> renameParamFromSidebar(WidgetTester tester, String newName) async {
  await tester.tap(find.byIcon(Icons.edit).first);
  await tester.pumpAndSettle();

  final dialog = find.byType(AlertDialog);
  final field = find.descendant(
    of: dialog,
    matching: find.byType(TextField)
  );
  final saveButton = find.descendant(
    of: dialog,
    matching: find.widgetWithText(TextButton, "Save")
  );

  await tester.enterText(field, newName);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

Future<EditorLoaded> dispatchEditorEvent(EditorBloc bloc, EditorEvent event) async {
  final nextState = bloc.stream.firstWhere((state) => state is EditorLoaded);
  bloc.add(event);
  final state = await nextState;
  return state as EditorLoaded;
}

Node<NodeObject> rootNode(EditorLoaded state) {
  return state.controller.nodes.values.firstWhere((node) {
    return node.data.nodeType == NodeType.experimentGen;
  });
}

List<String> paramNames(ParamSpace paramSpace) {
  return paramSpace.searchSpace.map((param) {
    return param.name;
  }).toList();
}

Map<String, dynamic> editorJsonWithParamRef(String name, {Map<String, List<dynamic>>? searchSpace}) {
  final paramValues = searchSpace ?? {
    name: [1, 2, 3]
  };

  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": {"param": name},
      "fold_size": 0.3
    },
    "param_space": {
      "search_space": paramValues
    }
  };
}

void main() {
  testWidgets("selecting a param updates the selector and disables literal input", (tester) async {
    final editorBloc = TestEditorBloc(
      paramSpace: ParamSpace(
        searchSpace: [
          Param(name: "threshold_param", type: ParamType.floatType, values: [0.5, 1.0])
        ]
      )
    );
    final node = buildNode(InputNode(threshold: 1.5));
    final nodeDataBloc = NodeDataBloc(node: node);

    addTearDown(() async {
      await nodeDataBloc.close();
      await editorBloc.close();
    });

    await tester.pumpWidget(
      buildTestApp(
        editorBloc: editorBloc,
        nodeDataBloc: nodeDataBloc,
        child: const NodeTextField(
          label: "threshold",
          fieldKey: "threshold",
          paramType: ParamType.floatType
        )
      )
    );

    final before = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey<String>("literal_wrapper_threshold"))
    );

    expect(before.ignoring, false);
    expect(find.text("literal"), findsOneWidget);

    await selectDropdownItem(
      tester,
      const ValueKey<String>("param_selector_threshold"),
      "threshold_param"
    );

    expect(node.data.paramRefs["threshold"], "threshold_param");

    final after = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey<String>("literal_wrapper_threshold"))
    );

    expect(after.ignoring, true);
    expect(find.text("threshold_param"), findsOneWidget);
  });

  testWidgets("node dropdown stays in sync across param binding and literal edits", (tester) async {
    final editorBloc = TestEditorBloc(
      paramSpace: ParamSpace(
        searchSpace: [
          Param(name: "returns_param", type: ParamType.stringType, values: ["log", "simple"])
        ]
      )
    );
    final node = buildNode(RawReturns(returnsType: ReturnsType.log));
    final nodeDataBloc = NodeDataBloc(node: node);

    addTearDown(() async {
      await nodeDataBloc.close();
      await editorBloc.close();
    });

    await tester.pumpWidget(
      buildTestApp(
        editorBloc: editorBloc,
        nodeDataBloc: nodeDataBloc,
        child: NodeDropdown<ReturnsType>(
          label: "returns",
          fieldKey: "returns_type",
          paramType: ParamType.stringType,
          options: ReturnsType.values,
          labelFor: (value) => value.name
        )
      )
    );

    expect(find.text("log"), findsOneWidget);

    await selectDropdownItem(
      tester,
      const ValueKey<String>("param_selector_returns_type"),
      "returns_param"
    );

    expect(node.data.paramRefs["returns_type"], "returns_param");

    final bound = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey<String>("literal_wrapper_returns_type"))
    );

    expect(bound.ignoring, true);

    await selectDropdownItem(
      tester,
      const ValueKey<String>("param_selector_returns_type"),
      "literal"
    );

    expect(node.data.paramRefs.containsKey("returns_type"), false);

    final unbound = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey<String>("literal_wrapper_returns_type"))
    );

    expect(unbound.ignoring, false);

    await selectDropdownItem(
      tester,
      const ValueKey<String>("node_dropdown_returns_type"),
      "simple"
    );

    final data = node.data as RawReturns;
    expect(data.returnsType, ReturnsType.simple);
    expect(find.text("simple"), findsOneWidget);
  });

  testWidgets("sidebar renders params in search space order", (tester) async {
    final bloc = TestEditorBloc(
      paramSpace: ParamSpace(
        searchSpace: [
          Param(name: "first_param", type: ParamType.intType, values: [1]),
          Param(name: "second_param", type: ParamType.intType, values: [2])
        ]
      )
    );

    addTearDown(() async {
      await bloc.close();
    });

    await tester.pumpWidget(
      buildEditorOnlyApp(
        editorBloc: bloc,
        child: const ParamSidebar()
      )
    );

    final firstPosition = tester.getTopLeft(find.text("first_param"));
    final secondPosition = tester.getTopLeft(find.text("second_param"));

    expect(firstPosition.dy < secondPosition.dy, true);
  });

  testWidgets("sidebar rename dialog updates the param name", (tester) async {
    final bloc = TestEditorBloc(
      paramSpace: ParamSpace(
        searchSpace: [
          Param(name: "folds", type: ParamType.intType, values: [1, 2, 3]),
          Param(name: "epochs", type: ParamType.intType, values: [4, 5, 6])
        ]
      )
    );

    addTearDown(() async {
      await bloc.close();
    });

    await tester.pumpWidget(
      buildEditorOnlyApp(
        editorBloc: bloc,
        child: const ParamSidebar()
      )
    );

    expect(find.text("folds"), findsOneWidget);

    await renameParamFromSidebar(tester, "rounds");

    final loaded = bloc.state as EditorLoaded;
    expect(paramNames(loaded.paramSpace), ["rounds", "epochs"]);
    expect(loaded.paramSpace.getParam("folds"), null);
    expect(loaded.paramSpace.getParam("rounds") != null, true);
    expect(find.text("rounds"), findsOneWidget);
  });

  testWidgets("sidebar rename dialog updates node param refs", (tester) async {
    final bloc = EditorBloc();
    addTearDown(bloc.close);

    await dispatchEditorEvent(
      bloc,
      LoadGraphFromJson(json: editorJsonWithParamRef("folds"))
    );

    await tester.pumpWidget(
      buildEditorOnlyApp(
        editorBloc: bloc,
        child: const ParamSidebar()
      )
    );

    await renameParamFromSidebar(tester, "rounds");

    final loaded = bloc.state as EditorLoaded;
    expect(rootNode(loaded).data.paramRefs["cv_folds"], "rounds");
    expect(loaded.paramSpace.getParam("rounds") != null, true);
  });

  test("ParamSpace appends params and rejects duplicate names", () {
    final paramSpace = ParamSpace(
      searchSpace: [
        Param(name: "folds", type: ParamType.intType, values: [1, 2]),
        Param(name: "rounds", type: ParamType.intType, values: [3, 4])
      ]
    );

    final added = paramSpace.addParam(
      Param(name: "epochs", type: ParamType.intType, values: [5, 6])
    );
    final duplicateAdd = paramSpace.addParam(
      Param(name: "rounds", type: ParamType.floatType, values: [0.1, 0.2])
    );

    expect(added, true);
    expect(duplicateAdd, false);
    expect(paramNames(paramSpace), ["folds", "rounds", "epochs"]);
  });

  test("ParamSpace renames in place and rejects duplicate names", () {
    final paramSpace = ParamSpace(
      searchSpace: [
        Param(name: "folds", type: ParamType.intType, values: [1, 2]),
        Param(name: "rounds", type: ParamType.intType, values: [3, 4]),
        Param(name: "epochs", type: ParamType.intType, values: [5, 6])
      ]
    );

    final renamed = paramSpace.renameParam("rounds", "trials");
    final duplicateRename = paramSpace.renameParam("trials", "folds");

    expect(renamed, true);
    expect(duplicateRename, false);
    expect(paramNames(paramSpace), ["folds", "trials", "epochs"]);
  });

  test("EditorBloc renames refs and clears them on type changes", () async {
    final bloc = EditorBloc();
    addTearDown(bloc.close);

    await dispatchEditorEvent(
      bloc,
      LoadGraphFromJson(json: editorJsonWithParamRef("folds"))
    );

    var loaded = await dispatchEditorEvent(
      bloc,
      const RenameParam(oldName: "folds", newName: "rounds")
    );

    expect(rootNode(loaded).data.paramRefs["cv_folds"], "rounds");

    loaded = await dispatchEditorEvent(
      bloc,
      const UpdateParamType(name: "rounds", type: ParamType.floatType)
    );

    expect(rootNode(loaded).data.paramRefs.containsKey("cv_folds"), false);
  });

  test("EditorBloc clears refs when removing params", () async {
    final bloc = EditorBloc();
    addTearDown(bloc.close);

    await dispatchEditorEvent(
      bloc,
      LoadGraphFromJson(
        json: editorJsonWithParamRef(
          "folds",
          searchSpace: {
            "folds": [1, 2, 3],
            "rounds": [4, 5, 6]
          }
        )
      )
    );

    final loaded = await dispatchEditorEvent(
      bloc,
      const RemoveParam(name: "folds")
    );

    expect(rootNode(loaded).data.paramRefs.containsKey("cv_folds"), false);
    expect(paramNames(loaded.paramSpace), ["rounds"]);
    expect(loaded.paramSpace.getParam("folds"), null);
  });
}
