import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/generator/editor_tree_item.dart";
import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/widgets/editor/experiment_gen_editor.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("generator JSON roundtrips through nested models", () {
    final root = ExperimentGenerator.fromJson(_generatorJson);
    final strategy = root.strategy;

    expect(strategy, isNotNull);
    expect(strategy!.featPool.length, 2);
    expect(strategy.baseNet?.logicNet?.nodes.length, 2);
    expect(root.toJson(), equals(_generatorJson));
  });

  test("schema adds and removes valid children only", () {
    final root = ExperimentGenerator(title: "Root");
    final strategy = ExperimentGenerator.createEmptyNode(NodeType.strategyGen);
    final addedStrategy = root.addChild("strategy", strategy);

    expect(addedStrategy, isTrue);
    expect(strategy, isA<Strategy>());
    expect(root.strategy, same(strategy));

    final invalid = ExperimentGenerator.createEmptyNode(NodeType.backtestSchema);
    final addedInvalid = root.addChild("strategy", invalid);
    expect(addedInvalid, isFalse);

    final strategyData = strategy as Strategy;
    final network = ExperimentGenerator.createEmptyNode(NodeType.networkGen);
    final addedNetwork = strategyData.addChild("base_net", network);

    expect(addedNetwork, isTrue);
    expect(network, isA<Network>());

    final removed = root.removeChild(network.nodeId);
    expect(removed, isTrue);
    expect(strategyData.baseNet, isNull);
  });

  test("editor tree separates object fields from labeled child slots", () async {
    final editorBloc = EditorBloc();
    editorBloc.add(LoadTreeFromJson(json: _wrapperJson));
    await Future<void>.delayed(Duration.zero);

    final loaded = editorBloc.state as EditorLoaded;
    final rootNode = loaded.tree.single;
    final rootItem = rootNode.content;
    final firstChildItem = rootNode.children.first.content;
    final slotItems = rootNode.children.map((node) => node.content).whereType<SlotTreeItem>().toList();

    expect(rootItem, isA<HeaderTreeItem>());
    expect(firstChildItem, isA<FieldsTreeItem>());
    expect(slotItems.map((item) => item.slot.label), containsAll(["Backtest", "Strategy"]));

    final backtestSlotNode = _slotNode(rootNode, "backtest_schema");
    final strategySlotNode = _slotNode(rootNode, "strategy");

    expect(backtestSlotNode.children.length, 1);
    expect(strategySlotNode.children.length, 1);
    expect(backtestSlotNode.children.single.content, isA<HeaderTreeItem>());
    expect(strategySlotNode.children.single.content, isA<HeaderTreeItem>());

    await editorBloc.close();
  });

  test("adding a child inserts it under the matching slot row", () async {
    final editorBloc = EditorBloc();
    editorBloc.add(LoadTreeFromJson(json: _emptyWrapperJson));
    await Future<void>.delayed(Duration.zero);

    var loaded = editorBloc.state as EditorLoaded;
    final root = loaded.root;
    final initialStrategySlot = _slotNode(loaded.tree.single, "strategy");

    expect(initialStrategySlot.children, isEmpty);

    editorBloc.add(AddTreeChild(
      parentId: root.nodeId,
      slotKey: "strategy",
      nodeType: NodeType.strategyGen
    ));
    await Future<void>.delayed(Duration.zero);

    loaded = editorBloc.state as EditorLoaded;
    final strategySlot = _slotNode(loaded.tree.single, "strategy");
    final strategyChild = strategySlot.children.single.content as HeaderTreeItem;

    expect(loaded.root.strategy, same(strategyChild.nodeData));
    expect(strategySlot.children.length, 1);
    expect(loaded.tree.single.children.where((node) => node.content is HeaderTreeItem), isEmpty);

    await editorBloc.close();
  });

  testWidgets("object and slot toggles collapse independently", (tester) async {
    final editorBloc = EditorBloc();
    addTearDown(editorBloc.close);
    editorBloc.add(LoadTreeFromJson(json: _wrapperJson));
    await tester.pump();

    final loaded = editorBloc.state as EditorLoaded;

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: editorBloc,
          child: const SizedBox(
            width: 900,
            height: 900,
            child: TreeEditor()
          )
        )
      )
    );
    await tester.pump();

    expect(find.text("title"), findsOneWidget);
    expect(find.text("Backtest (1)"), findsOneWidget);
    expect(find.text(NodeType.backtestSchema.value), findsOneWidget);

    await _tapToggleForRow(tester, NodeType.experimentGen.value);

    expect(find.text("title"), findsNothing);
    expect(find.text("Backtest (1)"), findsNothing);

    await _tapToggleForRow(tester, NodeType.experimentGen.value);

    expect(find.text("title"), findsOneWidget);
    expect(find.text("Backtest (1)"), findsOneWidget);
    expect(find.text(NodeType.backtestSchema.value), findsOneWidget);

    await _tapToggleForRow(tester, "Backtest (1)");

    expect(find.text("title"), findsOneWidget);
    expect(find.text("Backtest (1)"), findsOneWidget);
    expect(find.text(NodeType.backtestSchema.value), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  test("row edits do not emit editor structural state", () async {
    final editorBloc = EditorBloc();
    final editorStates = <EditorState>[];
    final editorSub = editorBloc.stream.listen(editorStates.add);

    editorBloc.add(LoadTreeFromJson(json: _wrapperJson));
    await Future<void>.delayed(Duration.zero);

    final loaded = editorBloc.state as EditorLoaded;
    final rowBloc = NodeDataBloc(nodeData: loaded.root);
    final rowStates = <NodeDataState>[];
    final rowSub = rowBloc.stream.listen(rowStates.add);

    rowBloc.add(const UpdateNodeField(fieldKey: "title", text: "Edited"));
    await Future<void>.delayed(Duration.zero);

    expect(loaded.root.title, "Edited");
    expect(rowStates.length, 1);
    expect(editorStates.length, 1);

    await rowSub.cancel();
    await editorSub.cancel();
    await rowBloc.close();
    await editorBloc.close();
  });
}

TreeSliverNode<EditorTreeItem> _slotNode(
  TreeSliverNode<EditorTreeItem> objectNode,
  String slotKey
) {
  for (final child in objectNode.children) {
    final item = child.content;
    if (item is SlotTreeItem && item.slot.key == slotKey) {
      return child;
    }
  }

  throw Exception("Missing slot node $slotKey");
}

Future<void> _tapToggleForRow(WidgetTester tester, String rowText) async {
  final textFinder = find.text(rowText);
  final rowTypeFinder = find.byType(Row);
  final rowMatches = find.ancestor(
    of: textFinder,
    matching: rowTypeFinder
  );
  final rowFinder = rowMatches.first;
  final iconPredicate = find.byWidgetPredicate(_isToggleIcon);
  final iconMatches = find.descendant(
    of: rowFinder,
    matching: iconPredicate
  );
  final iconFinder = iconMatches.first;

  await tester.tap(iconFinder);
  await tester.pump();
}

bool _isToggleIcon(Widget widget) {
  if (widget is! Icon) return false;
  final icon = widget.icon;
  if (icon == Icons.expand_more) return true;
  return icon == Icons.chevron_right;
}

final Map<String, dynamic> _wrapperJson = {
  "generator": _generatorJson,
  "param_space": {
    "search_space": {
      "pop_size": [50, 100],
      "default_value": [true, false]
    }
  }
};

final Map<String, dynamic> _emptyWrapperJson = {
  "generator": {
    "title": "Experiment",
    "val_size": 0.2,
    "test_size": 0.1,
    "cv_folds": 3,
    "fold_size": 0.3
  },
  "param_space": {
    "search_space": <String, dynamic>{}
  }
};

final Map<String, dynamic> _generatorJson = {
  "title": "Experiment",
  "val_size": 0.2,
  "test_size": 0.1,
  "cv_folds": 3,
  "fold_size": 0.3,
  "backtest_schema": {
    "start_offset": 10,
    "start_balance": 1000.0,
    "delay": 1
  },
  "strategy": {
    "base_net": {
      "type": "logic",
      "logic_net": {
        "node_pool": [
          {
            "id": "input_a",
            "type": "input",
            "threshold": 0.5,
            "feat_id": "returns"
          },
          {
            "id": "gate_a",
            "type": "gate",
            "gate": "and",
            "in1_idx": 0,
            "in2_idx": 0
          }
        ],
        "node_selection": ["gate_a"],
        "default_value": {"param": "default_value"}
      },
      "decision_net": {
        "node_pool": [
          {
            "id": "branch_a",
            "type": "branch",
            "threshold": 0.1,
            "feat_id": "returns",
            "true_idx": null,
            "false_idx": null
          },
          {
            "id": "ref_a",
            "type": "ref",
            "ref_idx": 0,
            "true_idx": null,
            "false_idx": null
          }
        ],
        "node_selection": ["branch_a"],
        "max_trail_len": 10,
        "default_value": false
      }
    },
    "feat_pool": [
      {
        "feature": "constant",
        "id": "constant_a",
        "constant": 1.0
      },
      {
        "feature": "raw_returns",
        "id": "returns",
        "returns_type": "log",
        "ohlc": "close"
      }
    ],
    "feat_selection": ["returns"],
    "actions": {
      "type": "logic",
      "logic_actions": {
        "meta_action_pool": [
          {
            "id": "hold",
            "type": "meta_action",
            "label": "Hold",
            "sub_actions": ["hold"]
          }
        ],
        "meta_action_selection": ["hold"],
        "threshold_pool": [
          {
            "id": "threshold_a",
            "type": "threshold",
            "feat_id": "returns",
            "min": -1.0,
            "max": 1.0
          }
        ],
        "threshold_selection": ["threshold_a"],
        "feat_order": ["returns"],
        "n_thresholds": 2,
        "allow_recurrence": true,
        "allowed_gates": ["and", "or"]
      },
      "decision_actions": {
        "meta_action_pool": [],
        "meta_action_selection": [],
        "threshold_pool": [],
        "threshold_selection": [],
        "feat_order": [],
        "n_thresholds": 0,
        "allow_refs": false
      }
    },
    "penalties": {
      "type": "logic",
      "logic_penalties": {
        "node": 1.0,
        "input": 0.1,
        "gate": 0.2,
        "recurrence": 0.3,
        "feedforward": 0.4,
        "used_feat": 0.5,
        "unused_feat": 0.6
      },
      "decision_penalties": {
        "node": 1.0,
        "branch": 0.1,
        "ref": 0.2,
        "leaf": 0.3,
        "non_leaf": 0.4,
        "used_feat": 0.5,
        "unused_feat": 0.6
      }
    },
    "stop_conds": {
      "max_iters": 100,
      "train_patience": 10,
      "val_patience": 5
    },
    "opt": {
      "type": "genetic",
      "pop_size": {"param": "pop_size"},
      "seq_len": 12,
      "n_elites": 2,
      "mut_rate": 0.05,
      "cross_rate": 0.8,
      "tournament_size": 3
    },
    "global_max_positions": 2,
    "entry_pool": [
      {
        "id": "entry_a",
        "node_ptr": {
          "anchor": "from_end",
          "idx": 0
        },
        "position_size": 1.0,
        "max_positions": 1
      }
    ],
    "entry_selection": ["entry_a"],
    "exit_pool": [
      {
        "id": "exit_a",
        "node_ptr": {
          "anchor": "from_end",
          "idx": 0
        },
        "entry_ids": ["entry_a"],
        "stop_loss": 0.02,
        "take_profit": 0.05,
        "max_hold_time": 20
      }
    ],
    "exit_selection": ["exit_a"]
  }
};
