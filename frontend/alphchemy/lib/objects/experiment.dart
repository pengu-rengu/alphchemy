import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class BacktestSchema extends NodeObject {
  int startOffset;
  double startBalance;
  int delay;

  @override
  String get nodeType => "backtest_schema";

  BacktestSchema({this.startOffset = 0, this.startBalance = 10000.0, this.delay = 1});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "startOffset": startOffset = int.tryParse(text) ?? 0;
      case "startBalance": startBalance = double.tryParse(text) ?? 0.0;
      case "delay": delay = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "startOffset" => startOffset.toString(),
      "startBalance" => startBalance.toString(),
      "delay" => delay.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final data = BacktestSchema(
      startOffset: intOrDefault(json, "start_offset", "startOffset", 0, refs),
      startBalance: doubleOrDefault(json, "start_balance", "startBalance", 10000.0, refs),
      delay: intOrDefault(json, "delay", "delay", 1, refs)
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as BacktestSchema;
    return {
      "start_offset": assembleField(data.startOffset, "startOffset", data.paramRefs),
      "start_balance": assembleField(data.startBalance, "startBalance", data.paramRefs),
      "delay": assembleField(data.delay, "delay", data.paramRefs)
    };
  }
}

class EntrySchema extends NodeObject {
  String entryId;
  double positionSize;
  int maxPositions;

  @override
  String get nodeType => "entry_schema";

  EntrySchema({
    this.entryId = "",
    this.positionSize = 0.1,
    this.maxPositions = 1
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "entryId": entryId = text;
      case "positionSize": positionSize = double.tryParse(text) ?? 0.0;
      case "maxPositions": maxPositions = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "entryId" => entryId,
      "positionSize" => positionSize.toString(),
      "maxPositions" => maxPositions.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["node_ptr"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    var nodePtrId = "";
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    if (nodePtrJson != null) {
      nodePtrId = NodePtr.flatten(ctx, nodePtrJson);
    }
    final refs = <String, String>{};
    final entryId = stringOrDefault(json, "id", "entryId", "", refs);
    final data = EntrySchema(
      entryId: entryId,
      positionSize: doubleOrDefault(json, "position_size", "positionSize", 0.1, refs),
      maxPositions: intOrDefault(json, "max_positions", "maxPositions", 1, refs)
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    if (nodePtrId.isNotEmpty) {
      ctx.connect(parentId, "out_node_ptr", nodePtrId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final nodePtrId = ctx.childId(nodeId, "out_node_ptr");
    final node = ctx.findNode(nodeId)!;
    final data = node.data as EntrySchema;
    return {
      "id": assembleField(data.entryId, "entryId", data.paramRefs),
      "node_ptr": nodePtrId != null
          ? NodePtr.assemble(ctx, nodePtrId)
          : null,
      "position_size": assembleField(data.positionSize, "positionSize", data.paramRefs),
      "max_positions": assembleField(data.maxPositions, "maxPositions", data.paramRefs)
    };
  }
}

class ExitSchema extends NodeObject {
  String exitId;
  List<String> entryIds;
  double stopLoss;
  double takeProfit;
  int maxHoldTime;

  @override
  String get nodeType => "exit_schema";

  ExitSchema({
    this.exitId = "",
    this.entryIds = const [],
    this.stopLoss = 0.0,
    this.takeProfit = 0.0,
    this.maxHoldTime = 0
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "exitId": exitId = text;
      case "entryIds": entryIds = NodeObject.parseStringList(text);
      case "stopLoss": stopLoss = double.tryParse(text) ?? 0.0;
      case "takeProfit": takeProfit = double.tryParse(text) ?? 0.0;
      case "maxHoldTime": maxHoldTime = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "exitId" => exitId,
      "entryIds" => NodeObject.formatList(entryIds),
      "stopLoss" => stopLoss.toString(),
      "takeProfit" => takeProfit.toString(),
      "maxHoldTime" => maxHoldTime.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["node_ptr"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    var nodePtrId = "";
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    if (nodePtrJson != null) {
      nodePtrId = NodePtr.flatten(ctx, nodePtrJson);
    }
    final refs = <String, String>{};
    final exitId = stringOrDefault(json, "id", "exitId", "", refs);
    final entryIds = stringListOrDefault(json, "entry_ids", "entryIds", const [], refs);
    final data = ExitSchema(
      exitId: exitId,
      entryIds: entryIds,
      stopLoss: doubleOrDefault(json, "stop_loss", "stopLoss", 0.0, refs),
      takeProfit: doubleOrDefault(json, "take_profit", "takeProfit", 0.0, refs),
      maxHoldTime: intOrDefault(json, "max_hold_time", "maxHoldTime", 0, refs)
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    if (nodePtrId.isNotEmpty) {
      ctx.connect(parentId, "out_node_ptr", nodePtrId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final nodePtrId = ctx.childId(nodeId, "out_node_ptr");
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ExitSchema;
    return {
      "id": assembleField(data.exitId, "exitId", data.paramRefs),
      "node_ptr": nodePtrId != null
          ? NodePtr.assemble(ctx, nodePtrId)
          : null,
      "entry_ids": assembleField(data.entryIds, "entryIds", data.paramRefs),
      "stop_loss": assembleField(data.stopLoss, "stopLoss", data.paramRefs),
      "take_profit": assembleField(data.takeProfit, "takeProfit", data.paramRefs),
      "max_hold_time": assembleField(data.maxHoldTime, "maxHoldTime", data.paramRefs)
    };
  }
}

class ActionsGen extends NodeObject {
  String type;

  @override
  String get nodeType => "actions_gen";

  ActionsGen({this.type = "logic"});

  @override
  void updateField(String fieldKey, String text) {}

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "type": type = value as String;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "type" => type,
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_actions", "decision_actions"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final type = stringOrDefault(json, "type", "type", "logic", refs);
    String? logicActionsId;
    String? decisionActionsId;
    final logicJson = json["logic_actions"] as Map<String, dynamic>?;
    if (logicJson != null) {
      logicActionsId = LogicActions.flatten(ctx, logicJson);
    }
    final decisionJson = json["decision_actions"] as Map<String, dynamic>?;
    if (decisionJson != null) {
      decisionActionsId = DecisionActions.flatten(ctx, decisionJson);
    }
    final data = ActionsGen(type: type);
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    if (logicActionsId != null) {
      ctx.connect(parentId, "out_logic_actions", logicActionsId);
    }
    if (decisionActionsId != null) {
      ctx.connect(parentId, "out_decision_actions", decisionActionsId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ActionsGen;
    final logicId = ctx.childId(nodeId, "out_logic_actions");
    final decisionId = ctx.childId(nodeId, "out_decision_actions");
    return {
      "type": assembleField(data.type, "type", data.paramRefs),
      "logic_actions": logicId != null
          ? LogicActions.assemble(ctx, logicId)
          : null,
      "decision_actions": decisionId != null
          ? DecisionActions.assemble(ctx, decisionId)
          : null
    };
  }
}

class StrategyGen extends NodeObject {
  List<String> featSelection;
  int globalMaxPositions;
  List<String> entrySelection;
  List<String> exitSelection;

  @override
  String get nodeType => "strategy_gen";

  StrategyGen({
    this.featSelection = const [],
    this.globalMaxPositions = 1,
    this.entrySelection = const [],
    this.exitSelection = const []
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "featSelection": featSelection = NodeObject.parseStringList(text);
      case "globalMaxPositions": globalMaxPositions = int.tryParse(text) ?? 1;
      case "entrySelection": entrySelection = NodeObject.parseStringList(text);
      case "exitSelection": exitSelection = NodeObject.parseStringList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "featSelection" => NodeObject.formatList(featSelection),
      "globalMaxPositions" => globalMaxPositions.toString(),
      "entrySelection" => NodeObject.formatList(entrySelection),
      "exitSelection" => NodeObject.formatList(exitSelection),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts([
        "base_net",
        "feat_pool",
        "actions",
        "penalties",
        "stop_conds",
        "opt",
        "entry_pool",
        "exit_pool"
      ])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    var baseNetId = "";
    final baseNetJson = json["base_net"] as Map<String, dynamic>?;
    if (baseNetJson != null) {
      baseNetId = NetworkGen.flatten(ctx, baseNetJson);
    }

    final featPoolIds = <String>[];
    final rawFeatPool = json["feat_pool"] as List<dynamic>?;
    if (rawFeatPool != null) {
      for (final raw in rawFeatPool) {
        final map = raw as Map<String, dynamic>;
        featPoolIds.add(StrategyGen.flattenFeature(ctx, map));
      }
    }
    final featSelection = stringListOrDefault(json, "feat_selection", "featSelection", const [], refs);

    var actionsId = "";
    final actionsJson = json["actions"] as Map<String, dynamic>?;
    if (actionsJson != null) {
      actionsId = ActionsGen.flatten(ctx, actionsJson);
    }

    var penaltiesId = "";
    final penaltiesJson = json["penalties"] as Map<String, dynamic>?;
    if (penaltiesJson != null) {
      penaltiesId = PenaltiesGen.flatten(ctx, penaltiesJson);
    }

    var stopCondsId = "";
    final stopCondsJson = json["stop_conds"] as Map<String, dynamic>?;
    if (stopCondsJson != null) {
      stopCondsId = StopConds.flatten(ctx, stopCondsJson);
    }

    var optId = "";
    final optJson = json["opt"] as Map<String, dynamic>?;
    if (optJson != null) {
      optId = GeneticOpt.flatten(ctx, optJson);
    }

    final globalMaxPositions = intOrDefault(json, "global_max_positions", "globalMaxPositions", 1, refs);

    final entryPoolIds = <String>[];
    final rawEntryPool = json["entry_pool"] as List<dynamic>?;
    if (rawEntryPool != null) {
      for (final raw in rawEntryPool) {
        final map = raw as Map<String, dynamic>;
        entryPoolIds.add(EntrySchema.flatten(ctx, map));
      }
    }
    final entrySelection = stringListOrDefault(json, "entry_selection", "entrySelection", const [], refs);

    final exitPoolIds = <String>[];
    final rawExitPool = json["exit_pool"] as List<dynamic>?;
    if (rawExitPool != null) {
      for (final raw in rawExitPool) {
        final map = raw as Map<String, dynamic>;
        exitPoolIds.add(ExitSchema.flatten(ctx, map));
      }
    }
    final exitSelection = stringListOrDefault(json, "exit_selection", "exitSelection", const [], refs);

    final data = StrategyGen(
      featSelection: featSelection,
      globalMaxPositions: globalMaxPositions,
      entrySelection: entrySelection,
      exitSelection: exitSelection
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    if (baseNetId.isNotEmpty) {
      ctx.connect(parentId, "out_base_net", baseNetId);
    }
    for (final childId in featPoolIds) {
      ctx.connect(parentId, "out_feat_pool", childId);
    }
    if (actionsId.isNotEmpty) {
      ctx.connect(parentId, "out_actions", actionsId);
    }
    if (penaltiesId.isNotEmpty) {
      ctx.connect(parentId, "out_penalties", penaltiesId);
    }
    if (stopCondsId.isNotEmpty) {
      ctx.connect(parentId, "out_stop_conds", stopCondsId);
    }
    if (optId.isNotEmpty) {
      ctx.connect(parentId, "out_opt", optId);
    }
    for (final childId in entryPoolIds) {
      ctx.connect(parentId, "out_entry_pool", childId);
    }
    for (final childId in exitPoolIds) {
      ctx.connect(parentId, "out_exit_pool", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final baseNetId = ctx.childId(nodeId, "out_base_net");
    final featIds = ctx.childIds(nodeId, "out_feat_pool");
    final actionsId = ctx.childId(nodeId, "out_actions");
    final penaltiesId = ctx.childId(nodeId, "out_penalties");
    final stopCondsId = ctx.childId(nodeId, "out_stop_conds");
    final optId = ctx.childId(nodeId, "out_opt");
    final entryIds = ctx.childIds(nodeId, "out_entry_pool");
    final exitIds = ctx.childIds(nodeId, "out_exit_pool");

    final node = ctx.findNode(nodeId)!;
    final data = node.data as StrategyGen;

    final featPoolList = featIds.map((id) {
      return StrategyGen.assembleFeature(ctx, id);
    }).toList();
    final entryPoolList = entryIds.map((id) {
      return EntrySchema.assemble(ctx, id);
    }).toList();
    final exitPoolList = exitIds.map((id) {
      return ExitSchema.assemble(ctx, id);
    }).toList();

    final result = <String, dynamic>{
      "feat_pool": featPoolList,
      "feat_selection": assembleField(data.featSelection, "featSelection", data.paramRefs),
      "global_max_positions": assembleField(data.globalMaxPositions, "globalMaxPositions", data.paramRefs),
      "entry_pool": entryPoolList,
      "entry_selection": assembleField(data.entrySelection, "entrySelection", data.paramRefs),
      "exit_pool": exitPoolList,
      "exit_selection": assembleField(data.exitSelection, "exitSelection", data.paramRefs)
    };
    if (baseNetId != null) {
      result["base_net"] = NetworkGen.assemble(ctx, baseNetId);
    }
    if (actionsId != null) {
      result["actions"] = ActionsGen.assemble(ctx, actionsId);
    }
    if (penaltiesId != null) {
      result["penalties"] = PenaltiesGen.assemble(ctx, penaltiesId);
    }
    if (stopCondsId != null) {
      result["stop_conds"] = StopConds.assemble(ctx, stopCondsId);
    }
    if (optId != null) {
      result["opt"] = GeneticOpt.assemble(ctx, optId);
    }
    return result;
  }

  static String flattenFeature(FlattenContext ctx, Map<String, dynamic> json) {
    final feature = json["feature"] as String;
    if (feature == "constant") {
      return ConstantFeature.flatten(ctx, json);
    }
    return RawReturnsFeature.flatten(ctx, json);
  }

  static Map<String, dynamic> assembleFeature(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    if (node.data is ConstantFeature) {
      return ConstantFeature.assemble(ctx, nodeId);
    }
    return RawReturnsFeature.assemble(ctx, nodeId);
  }
}

class ExperimentGenerator extends NodeObject {
  String title;
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;

  @override
  String get nodeType => "experiment_gen";

  ExperimentGenerator({
    this.title = "",
    this.valSize = 0.2,
    this.testSize = 0.1,
    this.cvFolds = 3,
    this.foldSize = 0.3
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "title": title = text;
      case "valSize": valSize = double.tryParse(text) ?? 0.0;
      case "testSize": testSize = double.tryParse(text) ?? 0.0;
      case "cvFolds": cvFolds = int.tryParse(text) ?? 0;
      case "foldSize": foldSize = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "title" => title,
      "valSize" => valSize.toString(),
      "testSize" => testSize.toString(),
      "cvFolds" => cvFolds.toString(),
      "foldSize" => foldSize.toString(),
      _ => ""
    };
  }

  static final nodeTypeToEmpty = <String, NodeObject Function()>{
    "experiment_gen": ExperimentGenerator.new,
    "backtest_schema": BacktestSchema.new,
    "strategy_gen": StrategyGen.new,
    "network_gen": NetworkGen.new,
    "logic_net": LogicNet.new,
    "decision_net": DecisionNet.new,
    "input_node": InputNode.new,
    "gate_node": GateNode.new,
    "branch_node": BranchNode.new,
    "ref_node": RefNode.new,
    "node_ptr": NodePtr.new,
    "constant_feature": ConstantFeature.new,
    "raw_returns_feature": RawReturnsFeature.new,
    "actions_gen": ActionsGen.new,
    "logic_actions": LogicActions.new,
    "decision_actions": DecisionActions.new,
    "meta_action": MetaAction.new,
    "threshold_range": ThresholdRange.new,
    "penalties_gen": PenaltiesGen.new,
    "logic_penalties": LogicPenalties.new,
    "decision_penalties": DecisionPenalties.new,
    "stop_conds": StopConds.new,
    "genetic_opt": GeneticOpt.new,
    "entry_schema": EntrySchema.new,
    "exit_schema": ExitSchema.new
  };

  static List<Port> ports() {
    return outputPorts(["backtest_schema", "strategy"]);
  }

  static GraphData flattenFromJson(Map<String, dynamic> json) {
    final ctx = FlattenContext();
    final refs = <String, String>{};

    final title = stringOrDefault(json, "title", "title", "", refs);
    final valSize = doubleOrDefault(json, "val_size", "valSize", 0.2, refs);
    final testSize = doubleOrDefault(json, "test_size", "testSize", 0.1, refs);
    final cvFolds = intOrDefault(json, "cv_folds", "cvFolds", 3, refs);
    final foldSize = doubleOrDefault(json, "fold_size", "foldSize", 0.3, refs);

    String backtestSchemaId = "";
    final backtestJson = json["backtest_schema"] as Map<String, dynamic>?;
    if (backtestJson != null) {
      backtestSchemaId = BacktestSchema.flatten(ctx, backtestJson);
    }

    String strategyId = "";
    final strategyJson = json["strategy"] as Map<String, dynamic>?;
    if (strategyJson != null) {
      strategyId = StrategyGen.flatten(ctx, strategyJson);
    } else {
      strategyId = ctx.addNode(StrategyGen());
    }

    final rootData = ExperimentGenerator(
      title: title,
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize
    );
    rootData.paramRefs.addAll(refs);
    final rootId = ctx.addNode(rootData);
    if (backtestSchemaId.isNotEmpty) {
      ctx.connect(rootId, "out_backtest_schema", backtestSchemaId);
    }
    ctx.connect(rootId, "out_strategy", strategyId);

    return GraphData(nodes: ctx.nodes, connections: ctx.connections);
  }

  static Map<String, dynamic> assembleToJson(List<Node<NodeObject>> nodes, List<Connection> connections) {
    final ctx = AssembleContext(nodes: nodes, connections: connections);

    Node<NodeObject>? rootNode;
    for (final node in nodes) {
      if (node.data.nodeType == "experiment_gen") {
        rootNode = node;
        break;
      }
    }

    final rootData = rootNode!.data as ExperimentGenerator;
    final strategyNodeId = ctx.childId(rootNode.id, "out_strategy")!;
    final backtestNodeId = ctx.childId(rootNode.id, "out_backtest_schema");

    final result = <String, dynamic>{
      "title": assembleField(rootData.title, "title", rootData.paramRefs),
      "val_size": assembleField(rootData.valSize, "valSize", rootData.paramRefs),
      "test_size": assembleField(rootData.testSize, "testSize", rootData.paramRefs),
      "cv_folds": assembleField(rootData.cvFolds, "cvFolds", rootData.paramRefs),
      "fold_size": assembleField(rootData.foldSize, "foldSize", rootData.paramRefs),
      "strategy": StrategyGen.assemble(ctx, strategyNodeId)
    };
    if (backtestNodeId != null) {
      result["backtest_schema"] = BacktestSchema.assemble(ctx, backtestNodeId);
    }
    return result;
  }
}
