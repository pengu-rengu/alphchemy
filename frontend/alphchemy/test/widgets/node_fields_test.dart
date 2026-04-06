import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/node_content/features.dart";
import "package:alphchemy/widgets/node_content/network.dart";
import "package:alphchemy/widgets/node_content/node_content.dart";
import "package:alphchemy/widgets/synced_text_field.dart";

void main() {
  group("Node text fields", () {
    testWidgets("node text field keeps decoration enabled", (
      WidgetTester tester,
    ) async {
      final nodeData = ExperimentGenerator();
      final node = Node<NodeObject>(
        id: "experiment",
        type: nodeData.nodeType,
        position: Offset.zero,
        data: nodeData,
        ports: ExperimentGenerator.ports(),
        size: const Size(250, 0),
      );
      final nodeDataBloc = NodeDataBloc(node: node);
      addTearDown(() async {
        await nodeDataBloc.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NodeDataBloc>.value(
            value: nodeDataBloc,
            child: const Scaffold(
              body: NodeTextField(label: "title", fieldKey: "title"),
            ),
          ),
        ),
      );
      await _pumpBlocQueue(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration, isNotNull);
    });

    testWidgets("synced text field keeps explicit decoration", (
      WidgetTester tester,
    ) async {
      const decoration = InputDecoration(labelText: "Name");

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncedTextField(
              text: "value",
              decoration: decoration,
              onChanged: _noop,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.labelText, decoration.labelText);
    });
  });

  group("Node dropdown fields", () {
    testWidgets("initial dropdown value comes from node data", (
      WidgetTester tester,
    ) async {
      final feature = RawReturnsFeature(
        returnsType: ReturnsType.simple,
        ohlc: OHLC.open,
      );
      final env = _buildFeatureHarness(feature: feature);
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_returnsDropdown(tester).value, ReturnsType.simple);
      expect(_ohlcDropdown(tester).value, OHLC.open);
    });

    testWidgets("dropdown updates after bloc field change", (
      WidgetTester tester,
    ) async {
      final feature = RawReturnsFeature(
        returnsType: ReturnsType.log,
        ohlc: OHLC.close,
      );
      final env = _buildFeatureHarness(feature: feature);
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      env.nodeDataBloc.add(
        const UpdateNodeFieldTyped(
          fieldKey: "returnsType",
          value: ReturnsType.simple,
        ),
      );
      await _pumpBlocQueue(tester);

      expect(_returnsDropdown(tester).value, ReturnsType.simple);
    });

    testWidgets("nullable gate dropdown uses formatted fallback", (
      WidgetTester tester,
    ) async {
      final gateNode = GateNode(gate: null);
      final env = _buildGateHarness(nodeData: gateNode);
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_gateDropdown(tester).value, Gate.and);
    });

    testWidgets("parameter bound dropdown stays disabled", (
      WidgetTester tester,
    ) async {
      final feature = RawReturnsFeature(
        returnsType: ReturnsType.log,
        ohlc: OHLC.close,
      );
      feature.paramRefs["returnsType"] = "mode";
      final editorBloc = TestEditorBloc();
      editorBloc.loadParams({
        "mode": Param(
          name: "mode",
          type: ParamType.stringType,
          values: ["log", "simple"],
        ),
      });
      final env = _buildFeatureHarness(
        feature: feature,
        editorBloc: editorBloc,
      );
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_returnsIgnorePointer(tester).ignoring, isTrue);
      expect(_returnsDropdown(tester).value, ReturnsType.log);
    });
  });

  group("Node checkbox fields", () {
    testWidgets("initial checkbox value comes from node data", (
      WidgetTester tester,
    ) async {
      final logicNet = LogicNet(defaultValue: true);
      final env = _buildLogicNetHarness(logicNet: logicNet);
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_nodeCheckbox(tester).value, isTrue);
    });

    testWidgets("checkbox updates after bloc field change", (
      WidgetTester tester,
    ) async {
      final logicNet = LogicNet(defaultValue: true);
      final env = _buildLogicNetHarness(logicNet: logicNet);
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      env.nodeDataBloc.add(
        const UpdateNodeFieldTyped(fieldKey: "defaultValue", value: false),
      );
      await _pumpBlocQueue(tester);

      expect(_nodeCheckbox(tester).value, isFalse);
    });

    testWidgets("parameter bound checkbox stays disabled", (
      WidgetTester tester,
    ) async {
      final logicNet = LogicNet(defaultValue: true);
      logicNet.paramRefs["defaultValue"] = "flag";
      final editorBloc = TestEditorBloc();
      editorBloc.loadParams({
        "flag": Param(
          name: "flag",
          type: ParamType.boolType,
          values: [true, false],
        ),
      });
      final env = _buildLogicNetHarness(
        logicNet: logicNet,
        editorBloc: editorBloc,
      );
      addTearDown(() async {
        await env.dispose();
      });

      await tester.pumpWidget(env.app);
      await _pumpBlocQueue(tester);

      expect(_checkboxIgnorePointer(tester).ignoring, isTrue);
      expect(_nodeCheckbox(tester).value, isTrue);
    });
  });

  group("Node content router", () {
    testWidgets("network node content hides idx fields", (
      WidgetTester tester,
    ) async {
      await _pumpNodeContent(
        tester,
        nodeData: InputNode(),
        ports: InputNode.ports(),
      );
      expect(find.text("idx"), findsNothing);

      await _pumpNodeContent(
        tester,
        nodeData: GateNode(),
        ports: GateNode.ports(),
      );
      expect(find.text("idx"), findsNothing);

      await _pumpNodeContent(
        tester,
        nodeData: BranchNode(),
        ports: BranchNode.ports(),
      );
      expect(find.text("idx"), findsNothing);

      await _pumpNodeContent(
        tester,
        nodeData: RefNode(),
        ports: RefNode.ports(),
      );
      expect(find.text("idx"), findsNothing);
    });

    testWidgets("routes node types from each content group", (
      WidgetTester tester,
    ) async {
      await _pumpNodeContent(
        tester,
        nodeData: ExperimentGenerator(),
        ports: ExperimentGenerator.ports(),
      );
      expect(find.text("cvFolds"), findsOneWidget);

      await _pumpNodeContent(
        tester,
        nodeData: RawReturnsFeature(),
        ports: RawReturnsFeature.ports(),
      );
      expect(find.text("returns"), findsOneWidget);

      await _pumpNodeContent(
        tester,
        nodeData: GateNode(),
        ports: GateNode.ports(),
      );
      expect(find.text("in1Idx"), findsOneWidget);

      await _pumpNodeContent(
        tester,
        nodeData: LogicActions(),
        ports: LogicActions.ports(),
      );
      expect(find.text("recurrence"), findsOneWidget);

      await _pumpNodeContent(
        tester,
        nodeData: GeneticOpt(),
        ports: GeneticOpt.ports(),
      );
      expect(find.text("crossRate"), findsOneWidget);
    });
  });
}

class _Harness {
  final MaterialApp app;
  final EditorBloc editorBloc;
  final NodeDataBloc nodeDataBloc;

  _Harness({
    required this.app,
    required this.editorBloc,
    required this.nodeDataBloc,
  });

  Future<void> dispose() async {
    await editorBloc.close();
    await nodeDataBloc.close();
  }
}

class TestEditorBloc extends EditorBloc {
  void loadParams(Map<String, Param> params) {
    emit(EditorInitial(params: params));
  }
}

_Harness _buildFeatureHarness({
  required RawReturnsFeature feature,
  EditorBloc? editorBloc,
}) {
  final currentEditorBloc = editorBloc ?? TestEditorBloc();
  final node = Node<NodeObject>(
    id: "feature",
    type: feature.nodeType,
    position: Offset.zero,
    data: feature,
    ports: RawReturnsFeature.ports(),
    size: const Size(250, 0),
  );
  final nodeDataBloc = NodeDataBloc(node: node);

  final app = MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<EditorBloc>.value(value: currentEditorBloc),
        BlocProvider<NodeDataBloc>.value(value: nodeDataBloc),
      ],
      child: Scaffold(
        body: BlocBuilder<NodeDataBloc, NodeDataState>(
          builder: (context, state) {
            return RawReturnsFeatureContent(key: ValueKey(state.version));
          },
        ),
      ),
    ),
  );

  return _Harness(
    app: app,
    editorBloc: currentEditorBloc,
    nodeDataBloc: nodeDataBloc,
  );
}

_Harness _buildGateHarness({required GateNode nodeData}) {
  final editorBloc = TestEditorBloc();
  final node = Node<NodeObject>(
    id: "gate",
    type: nodeData.nodeType,
    position: Offset.zero,
    data: nodeData,
    ports: GateNode.ports(),
    size: const Size(250, 0),
  );
  final nodeDataBloc = NodeDataBloc(node: node);

  final app = MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<EditorBloc>.value(value: editorBloc),
        BlocProvider<NodeDataBloc>.value(value: nodeDataBloc),
      ],
      child: Scaffold(
        body: BlocBuilder<NodeDataBloc, NodeDataState>(
          builder: (context, state) {
            return GateNodeContent(key: ValueKey(state.version));
          },
        ),
      ),
    ),
  );

  return _Harness(app: app, editorBloc: editorBloc, nodeDataBloc: nodeDataBloc);
}

_Harness _buildLogicNetHarness({
  required LogicNet logicNet,
  EditorBloc? editorBloc,
}) {
  final currentEditorBloc = editorBloc ?? TestEditorBloc();
  final node = Node<NodeObject>(
    id: "logic",
    type: logicNet.nodeType,
    position: Offset.zero,
    data: logicNet,
    ports: LogicNet.ports(),
    size: const Size(250, 0),
  );
  final nodeDataBloc = NodeDataBloc(node: node);

  final app = MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<EditorBloc>.value(value: currentEditorBloc),
        BlocProvider<NodeDataBloc>.value(value: nodeDataBloc),
      ],
      child: Scaffold(
        body: BlocBuilder<NodeDataBloc, NodeDataState>(
          builder: (context, state) {
            return LogicNetContent(key: ValueKey(state.version));
          },
        ),
      ),
    ),
  );

  return _Harness(
    app: app,
    editorBloc: currentEditorBloc,
    nodeDataBloc: nodeDataBloc,
  );
}

DropdownButton<ReturnsType> _returnsDropdown(WidgetTester tester) {
  final finder = find.byWidgetPredicate((Widget widget) {
    return widget is DropdownButton<ReturnsType>;
  });
  return tester.widget<DropdownButton<ReturnsType>>(finder);
}

DropdownButton<OHLC> _ohlcDropdown(WidgetTester tester) {
  final finder = find.byWidgetPredicate((Widget widget) {
    return widget is DropdownButton<OHLC>;
  });
  return tester.widget<DropdownButton<OHLC>>(finder);
}

DropdownButton<Gate> _gateDropdown(WidgetTester tester) {
  final finder = find.byWidgetPredicate((Widget widget) {
    return widget is DropdownButton<Gate>;
  });
  return tester.widget<DropdownButton<Gate>>(finder);
}

IgnorePointer _returnsIgnorePointer(WidgetTester tester) {
  final dropdown = find.byWidgetPredicate((Widget widget) {
    return widget is DropdownButton<ReturnsType>;
  });
  final ignorePointer = find
      .ancestor(of: dropdown, matching: find.byType(IgnorePointer))
      .first;
  return tester.widget<IgnorePointer>(ignorePointer);
}

Checkbox _nodeCheckbox(WidgetTester tester) {
  return tester.widget<Checkbox>(find.byType(Checkbox));
}

IgnorePointer _checkboxIgnorePointer(WidgetTester tester) {
  final checkbox = find.byType(Checkbox);
  final ignorePointer = find
      .ancestor(of: checkbox, matching: find.byType(IgnorePointer))
      .first;
  return tester.widget<IgnorePointer>(ignorePointer);
}

Future<void> _pumpBlocQueue(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpNodeContent(
  WidgetTester tester, {
  required NodeObject nodeData,
  required List<Port> ports,
}) async {
  final editorBloc = TestEditorBloc();
  addTearDown(() async {
    await editorBloc.close();
  });

  final node = Node<NodeObject>(
    id: nodeData.nodeType,
    type: nodeData.nodeType,
    position: Offset.zero,
    data: nodeData,
    ports: ports,
    size: const Size(250, 0),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<EditorBloc>.value(
        value: editorBloc,
        child: Scaffold(body: NodeContent(node: node)),
      ),
    ),
  );
  await _pumpBlocQueue(tester);
}

void _noop(String value) {}
