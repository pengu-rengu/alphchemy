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

  test("updating parameter values text parses in the bloc", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(AddParam(
      param: Param(
        name: "choices",
        type: ParamType.intListType,
        values: const []
      )
    ));
    await _waitForState(bloc);

    bloc.add(UpdateParam(oldName: "choices", valuesText: "1, nope, 3; 4, 5"));
    await _waitForState(bloc);

    final param = bloc.state.params["choices"]!;
    expect(param.values, [
      [1, 3],
      [4, 5]
    ]);
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

  test("load graph keeps flat int params scalar", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _intListParamWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["max_pos"]!;
    expect(param.type, ParamType.intType);
    expect(param.values, [1, 2, 4]);

    final export = bloc.exportToJson();
    final paramSpace = export["param_space"] as Map<String, dynamic>;
    final searchSpace = paramSpace["search_space"] as Map<String, dynamic>;
    expect(searchSpace["max_pos"], [1, 2, 4]);
  });

  test("load graph infers string-list selection params", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _selectionStringListWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["feat_sel"]!;
    expect(param.type, ParamType.stringListType);
    expect(param.values, [
      ["feat_1", "feat_2"],
      ["feat_3"]
    ]);
  });

  test("load graph keeps flat string params scalar", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _stringListParamWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["sub_actions_param"]!;
    expect(param.type, ParamType.stringType);
    expect(param.values, ["buy", "sell"]);
  });

  test("load graph infers nested string list params", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _nestedStringListWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["named_lists"]!;
    expect(param.type, ParamType.stringListType);
    expect(param.values, [
      ["buy", "sell"],
      ["hold"]
    ]);
  });

  test("load graph defaults empty params to string", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _emptyParamWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["empty_param"]!;
    expect(param.type, ParamType.stringType);
    expect(param.values, isEmpty);
  });

  test("load graph keeps nested empty lists raw", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _nestedEmptyListWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["empty_lists"]!;
    expect(param.type, ParamType.stringListType);
    expect(param.values, [
      [],
      []
    ]);
  });

  test("load graph keeps raw malformed list values", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: _rawListWrapperJson()));
    await _waitForState(bloc);

    final param = bloc.state.params["raw_list"]!;
    expect(param.type, ParamType.intListType);
    expect(param.values, [
      [1, "nope"],
      []
    ]);

    final export = bloc.exportToJson();
    final paramSpace = export["param_space"] as Map<String, dynamic>;
    final searchSpace = paramSpace["search_space"] as Map<String, dynamic>;
    expect(searchSpace["raw_list"], [
      [1, "nope"],
      []
    ]);
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

  test("adding selectable nodes assigns default ids", () async {
    final bloc = EditorBloc();
    addTearDown(() async {
      await bloc.close();
    });

    bloc.add(LoadGraphFromJson(json: mockWrapperJson));
    await _waitForState(bloc);

    final controller = _loadedController(bloc);

    bloc.add(AddNode(nodeType: "constant_feature"));
    await _flushEventQueue();
    bloc.add(AddNode(nodeType: "raw_returns_feature"));
    await _flushEventQueue();

    final constantNode = controller.getNodesByType("constant_feature").single;
    final returnsNode = controller.getNodesByType("raw_returns_feature").single;

    expect(constantNode.data.formatField("featId"), "feat_1");
    expect(returnsNode.data.formatField("featId"), "feat_2");
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

Map<String, dynamic> _intListParamWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3,
      "strategy": {
        "feat_pool": [],
        "feat_selection": [],
        "global_max_positions": {"key": "max_pos"},
        "entry_pool": [],
        "entry_selection": [],
        "exit_pool": [],
        "exit_selection": []
      }
    },
    "param_space": {
      "search_space": {
        "max_pos": [1, 2, 4]
      }
    }
  };
}

Map<String, dynamic> _selectionStringListWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3,
      "strategy": {
        "feat_pool": [],
        "feat_selection": {"key": "feat_sel"},
        "global_max_positions": 1,
        "entry_pool": [],
        "entry_selection": [],
        "exit_pool": [],
        "exit_selection": []
      }
    },
    "param_space": {
      "search_space": {
        "feat_sel": [
          ["feat_1", "feat_2"],
          ["feat_3"]
        ]
      }
    }
  };
}

Map<String, dynamic> _stringListParamWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3,
      "strategy": {
        "feat_pool": [],
        "feat_selection": [],
        "actions": {
          "type": "logic",
          "logic_actions": {
            "meta_action_pool": [
              {
                "id": "meta_1",
                "label": "combo",
                "sub_actions": {"key": "sub_actions_param"}
              }
            ],
            "meta_action_selection": [],
            "threshold_pool": [],
            "threshold_selection": [],
            "n_thresholds": 0,
            "allow_recurrence": false,
            "allowed_gates": []
          }
        },
        "global_max_positions": 1,
        "entry_pool": [],
        "entry_selection": [],
        "exit_pool": [],
        "exit_selection": []
      }
    },
    "param_space": {
      "search_space": {
        "sub_actions_param": ["buy", "sell"]
      }
    }
  };
}

Map<String, dynamic> _nestedStringListWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3
    },
    "param_space": {
      "search_space": {
        "named_lists": [
          ["buy", "sell"],
          ["hold"]
        ]
      }
    }
  };
}

Map<String, dynamic> _emptyParamWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3
    },
    "param_space": {
      "search_space": {
        "empty_param": []
      }
    }
  };
}

Map<String, dynamic> _nestedEmptyListWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3
    },
    "param_space": {
      "search_space": {
        "empty_lists": [
          [],
          []
        ]
      }
    }
  };
}

Map<String, dynamic> _rawListWrapperJson() {
  return {
    "generator": {
      "title": "Experiment",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 3,
      "fold_size": 0.3
    },
    "param_space": {
      "search_space": {
        "raw_list": [
          [1, "nope"],
          []
        ]
      }
    }
  };
}
