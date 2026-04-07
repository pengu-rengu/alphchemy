import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

void main() {
  group("Parameter bindings", () {
    testWidgets("changing a parameter type clears bound refs", (
      WidgetTester tester,
    ) async {
      final env = _buildHarness(
        paramName: "rate",
        paramType: ParamType.floatType,
        currentRef: "rate",
      );
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_fieldIgnorePointer(tester).ignoring, isTrue);

      env.editorBloc.add(
        UpdateParam(
          oldName: "rate",
          param: Param(name: "rate", type: ParamType.stringType, values: []),
        ),
      );
      await _pumpBlocQueue(tester);

      expect(env.feature.paramRefs.containsKey("constant"), isFalse);
      expect(_fieldIgnorePointer(tester).ignoring, isFalse);
      expect(_constantJsonValue(env.editorBloc.exportToJson()), 1.5);
    });

    testWidgets("deleting a parameter clears bound refs", (
      WidgetTester tester,
    ) async {
      final env = _buildHarness(
        paramName: "rate",
        paramType: ParamType.floatType,
        currentRef: "rate",
      );
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      env.editorBloc.add(const RemoveParam(name: "rate"));
      await _pumpBlocQueue(tester);

      expect(env.feature.paramRefs.containsKey("constant"), isFalse);
      expect(env.editorBloc.state.params.containsKey("rate"), isFalse);
      expect(_fieldIgnorePointer(tester).ignoring, isFalse);
      expect(_constantJsonValue(env.editorBloc.exportToJson()), 1.5);
    });

    testWidgets("renaming a parameter keeps matching refs bound", (
      WidgetTester tester,
    ) async {
      final env = _buildHarness(
        paramName: "rate",
        paramType: ParamType.floatType,
        currentRef: "rate",
      );
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      env.editorBloc.add(
        UpdateParam(
          oldName: "rate",
          param: Param(
            name: "new_rate",
            type: ParamType.floatType,
            values: [0.1, 0.2],
          ),
        ),
      );
      await _pumpBlocQueue(tester);

      expect(env.feature.paramRefs["constant"], "new_rate");
      expect(_fieldIgnorePointer(tester).ignoring, isTrue);
      expect(env.editorBloc.state.params.containsKey("rate"), isFalse);
      expect(env.editorBloc.state.params.containsKey("new_rate"), isTrue);
      expect(_constantJsonValue(env.editorBloc.exportToJson()), {
        "param": "new_rate",
      });
    });

    testWidgets("invalid preloaded refs render as literal", (
      WidgetTester tester,
    ) async {
      final env = _buildHarness(
        paramName: "name",
        paramType: ParamType.stringType,
        currentRef: "missing_param",
      );
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_fieldIgnorePointer(tester).ignoring, isFalse);
      expect(_selectorDropdown(tester).value, isNull);
    });
  });
}

class _Harness {
  final MaterialApp app;
  final TestEditorBloc editorBloc;
  final Constant feature;

  _Harness({
    required this.app,
    required this.editorBloc,
    required this.feature,
  });

  Future<void> dispose() async {
    await editorBloc.close();
  }
}

class TestEditorBloc extends EditorBloc {
  void loadState({
    required NodeFlowController<NodeObject, void> controller,
    required Map<String, Param> params,
  }) {
    emit(EditorLoaded(controller: controller, params: params));
  }
}

_Harness _buildHarness({
  required String paramName,
  required ParamType paramType,
  required String currentRef,
}) {
  final editorBloc = TestEditorBloc();

  final feature = Constant(constant: 1.5);
  feature.paramRefs["constant"] = currentRef;

  final rootNode = Node<NodeObject>(
    id: "root",
    type: NodeType.experimentGen.value,
    position: Offset.zero,
    data: ExperimentGenerator(),
    ports: ExperimentGenerator.ports(),
    size: const Size(250, 0),
  );
  final strategyNode = Node<NodeObject>(
    id: "strategy",
    type: NodeType.strategyGen.value,
    position: Offset.zero,
    data: Strategy(),
    ports: Strategy.ports(),
    size: const Size(250, 0),
  );
  final featureNode = Node<NodeObject>(
    id: "feature",
    type: feature.nodeType.value,
    position: Offset.zero,
    data: feature,
    ports: Constant.ports(),
    size: const Size(250, 0),
  );

  final connections = [
    Connection(
      id: "root-strategy",
      sourceNodeId: "root",
      sourcePortId: "strategy",
      targetNodeId: "strategy",
      targetPortId: "in",
    ),
    Connection(
      id: "strategy-feature",
      sourceNodeId: "strategy",
      sourcePortId: "feat_pool",
      targetNodeId: "feature",
      targetPortId: "in",
    ),
  ];

  final controller = NodeFlowController<NodeObject, void>(
    nodes: [rootNode, strategyNode, featureNode],
    connections: connections,
  );
  final values = _valuesForType(paramType);
  final params = {
    paramName: Param(name: paramName, type: paramType, values: values),
  };
  editorBloc.loadState(controller: controller, params: params);

  final fieldApp = MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<EditorBloc>.value(value: editorBloc),
        BlocProvider(create: (_) => NodeDataBloc(node: featureNode)),
      ],
      child: const Scaffold(
        body: NodeTextField(
          label: "constant",
          fieldKey: "constant",
          paramType: ParamType.floatType,
        ),
      ),
    ),
  );

  return _Harness(app: fieldApp, editorBloc: editorBloc, feature: feature);
}

List<dynamic> _valuesForType(ParamType type) {
  switch (type) {
    case ParamType.intType:
      return [1, 2];
    case ParamType.floatType:
      return [0.1, 0.2];
    case ParamType.stringType:
      return ["a", "b"];
    case ParamType.boolType:
      return [true, false];
    case ParamType.intListType:
      return [
        [1, 2],
        [3, 4],
      ];
    case ParamType.stringListType:
      return [
        ["a", "b"],
        ["c"],
      ];
  }
}

IgnorePointer _fieldIgnorePointer(WidgetTester tester) {
  final textField = find.byType(TextField).first;
  final ignorePointer = find
      .ancestor(of: textField, matching: find.byType(IgnorePointer))
      .first;
  return tester.widget<IgnorePointer>(ignorePointer);
}

DropdownButton<String?> _selectorDropdown(WidgetTester tester) {
  final finder = find.byWidgetPredicate((widget) {
    return widget is DropdownButton<String?>;
  });
  return tester.widget<DropdownButton<String?>>(finder);
}

dynamic _constantJsonValue(Map<String, dynamic> wrapperJson) {
  final generator = wrapperJson["generator"] as Map<String, dynamic>;
  final strategy = generator["strategy"] as Map<String, dynamic>;
  final featPool = strategy["feat_pool"] as List<dynamic>;
  final constantFeature = featPool.first as Map<String, dynamic>;
  return constantFeature["constant"];
}

Future<void> _pumpBlocQueue(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
