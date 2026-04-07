import "dart:math";

import "package:alphchemy/model/generator/actions.dart";
import "package:alphchemy/model/generator/features.dart";
import "package:alphchemy/model/generator/graph_convert.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/node_ports.dart";
import "package:alphchemy/model/generator/optimizer.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class BacktestSchema extends NodeObject {
  int startOffset;
  double startBalance;
  int delay;

  @override
  NodeType get nodeType => NodeType.backtestSchema;

  BacktestSchema({this.startOffset = 0, this.startBalance = 0.0, this.delay = 0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "start_offset": startOffset = int.tryParse(text) ?? 0;
      case "start_balance": startBalance = double.tryParse(text) ?? 0.0;
      case "delay": delay = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "start_offset" => startOffset.toString(),
      "start_balance" => startBalance.toString(),
      "delay" => delay.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final startOffset = getField<int>(json, "start_offset", 0, paramRefs);
    final startBalance = getField<double>(json, "start_balance", 0.0, paramRefs,doubleFromJson);
    final delay = getField<int>(json, "delay", 0, paramRefs);

    final data = BacktestSchema(
      startOffset: startOffset,
      startBalance: startBalance,
      delay: delay,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as BacktestSchema;

    final startOffset = assembleField(data.startOffset, "start_offset", data);
    final startBalance =  assembleField(data.startBalance, "start_balance", data);
    final delay = assembleField(data.delay, "delay", data);

    return {
      "start_offset": startOffset,
      "start_balance": startBalance,
      "delay": delay
    };
  }
}

class EntrySchema extends NodeObject {
  String id;
  double positionSize;
  int maxPositions;

  @override
  NodeType get nodeType => NodeType.entrySchema;

  EntrySchema({
    this.id = "",
    this.positionSize = 0.0,
    this.maxPositions = 0,
    super.paramRefs
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": id = text;
      case "position_size": positionSize = double.tryParse(text) ?? 0.0;
      case "max_positions": maxPositions = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "position_size" => positionSize.toString(),
      "max_positions" => maxPositions.toString(),
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
    final paramRefs = <String, String>{};

    final id = getField<String>(json, "id", "", paramRefs);
    final positionSize = getField<double>(json, "position_size", 0.0, paramRefs, doubleFromJson);
    final maxPositions = getField<int>(json, "max_positions", 0, paramRefs);

    final data = EntrySchema(
      id: id,
      positionSize: positionSize,
      maxPositions: maxPositions,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    if (nodePtrJson != null) {
      final nodePtrId = NodePtr.flatten(ctx, nodePtrJson);
      ctx.connect(parentId, "node_ptr", nodePtrId);
    }

    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as EntrySchema;

    final id = assembleField(data.id, "id", data);

    final nodePtrId = ctx.childId(nodeId, "node_ptr");
    final nodePtr = nodePtrId != null ? NodePtr.assemble(ctx, nodePtrId) : null;

    final positionSize = assembleField(data.positionSize, "position_size", data);
    final maxPositions = assembleField(data.maxPositions, "max_positions", data);

    return {
      "id": id,
      "node_ptr": nodePtr,
      "position_size": positionSize,
      "max_positions": maxPositions
    };
  }
}

class ExitSchema extends NodeObject {
  String id;
  List<String> entryIds;
  double stopLoss;
  double takeProfit;
  int maxHoldTime;

  @override
  NodeType get nodeType => NodeType.exitSchema;

  ExitSchema({this.id = "", this.entryIds = const [], this.stopLoss = 0.0, this.takeProfit = 0.0, this.maxHoldTime = 0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": id = text;
      case "entry_ids": entryIds = parseList(text);
      case "stop_loss": stopLoss = double.tryParse(text) ?? 0.0;
      case "take_profit": takeProfit = double.tryParse(text) ?? 0.0;
      case "max_hold_time": maxHoldTime = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "entry_ids" => entryIds.join(", "),
      "stop_loss" => stopLoss.toString(),
      "take_profit" => takeProfit.toString(),
      "max_hold_time" => maxHoldTime.toString(),
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
    final paramRefs = <String, String>{};

    final id = getField<String>(json, "id", "", paramRefs);
    final entryIds = getField<List<String>>(json, "entry_ids", const [], paramRefs, listFromJson<String>);
    final stopLoss = getField<double>(json, "stop_loss", 0.0, paramRefs, doubleFromJson);
    final takeProfit = getField<double>(json, "take_profit", 0.0, paramRefs, doubleFromJson);
    final maxHoldTime = getField<int>(json, "max_hold_time", 0, paramRefs);

    final data = ExitSchema(
      id: id,
      entryIds: entryIds,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    if (nodePtrJson != null) {
      final nodePtrId = NodePtr.flatten(ctx, nodePtrJson);
      ctx.connect(parentId, "node_ptr", nodePtrId);
    }

    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    
    final data = ctx.findNode(nodeId).data as ExitSchema;

    final id =  assembleField(data.id, "id", data);

    final nodePtrId = ctx.childId(nodeId, "node_ptr");
    final nodePtr = nodePtrId != null ? NodePtr.assemble(ctx, nodePtrId) : null;

    final entryIds = assembleField(data.entryIds, "entry_ids", data);
    final stopLoss = assembleField(data.stopLoss, "stop_loss", data);
    final takeProfit = assembleField(data.takeProfit, "take_profit", data);
    final maxHoldTime = assembleField(data.maxHoldTime, "max_hold_time", data);

    return {
      "id": id,
      "node_ptr": nodePtr,
      "entry_ids": entryIds,
      "stop_loss": stopLoss,
      "take_profit": takeProfit,
      "max_hold_time": maxHoldTime
    };
  }
}

class Strategy extends NodeObject {
  List<String> featSelection;
  int globalMaxPositions;
  List<String> entrySelection;
  List<String> exitSelection;

  @override
  NodeType get nodeType => NodeType.strategyGen;

  Strategy({this.featSelection = const [], this.globalMaxPositions = 1, this.entrySelection = const [], this.exitSelection = const [], super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "feat_selection": featSelection = parseList(text);
      case "global_max_positions": globalMaxPositions = int.tryParse(text) ?? 1;
      case "entry_selection": entrySelection = parseList(text);
      case "exit_selection": exitSelection = parseList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "feat_selection" => featSelection.join(", "),
      "global_max_positions" => globalMaxPositions.toString(),
      "entry_selection" => entrySelection.join(", "),
      "exit_selection" => exitSelection.join(", "),
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
    final paramRefs = <String, String>{};

    final featSelection = getField<List<String>>(json, "feat_selection", const [], paramRefs, listFromJson<String>);
    final globalMaxPositions = getField<int>(json, "global_max_positions", 1, paramRefs);
    final entrySelection = getField<List<String>>(json, "entry_selection", const [], paramRefs, listFromJson<String>);
    final exitSelection = getField<List<String>>(json, "exit_selection", const [], paramRefs, listFromJson<String>);

    final data = Strategy(
      featSelection: featSelection,
      globalMaxPositions: globalMaxPositions,
      entrySelection: entrySelection,
      exitSelection: exitSelection,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    final baseNetJson = json["base_net"] as Map<String, dynamic>?;
    if (baseNetJson != null) {
      final baseNetId = Network.flatten(ctx, baseNetJson);
      ctx.connect(parentId, "base_net", baseNetId);
    }

    for (final featJson in json["feat_pool"] as List<dynamic>? ?? []) {
      final featId = flattenFeat(ctx, featJson as Map<String, dynamic>);
      ctx.connect(parentId, "feat_pool", featId);
    }

    final actionsJson = json["actions"] as Map<String, dynamic>?;
    if (actionsJson != null) {
      final actionsId = Actions.flatten(ctx, actionsJson);
      ctx.connect(parentId, "actions", actionsId);
    }

    final penaltiesJson = json["penalties"] as Map<String, dynamic>?;
    if (penaltiesJson != null) {
      final penaltiesId = Penalties.flatten(ctx, penaltiesJson);
      ctx.connect(parentId, "penalties", penaltiesId);
    }

    final stopCondsJson = json["stop_conds"] as Map<String, dynamic>?;
    if (stopCondsJson != null) {
      final stopCondsId = StopConds.flatten(ctx, stopCondsJson);
      ctx.connect(parentId, "stop_conds", stopCondsId);
    }

    final optJson = json["opt"] as Map<String, dynamic>?;
    if (optJson != null) {
      final optId = GeneticOpt.flatten(ctx, optJson);
      ctx.connect(parentId, "opt", optId);
    }

    for (final entryJson in json["entry_pool"] as List<dynamic>? ?? []) {
      final entryId = EntrySchema.flatten(ctx, entryJson as Map<String, dynamic>);
      ctx.connect(parentId, "entry_pool", entryId);
    }

    for (final exitJson in json["exit_pool"] as List<dynamic>? ?? []) {
      final exitId = ExitSchema.flatten(ctx, exitJson as Map<String, dynamic>);
      ctx.connect(parentId, "exit_pool", exitId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as Strategy;

    final baseNetId = ctx.childId(nodeId, "base_net");
    final baseNet = baseNetId != null ? Network.assemble(ctx, baseNetId) : null;

    final featIds = ctx.childIds(nodeId, "feat_pool");
    Map<String, dynamic> assembleFeat(id) => Strategy.assembleFeat(ctx, id);
    final featPool = featIds.map(assembleFeat).toList();

    final featSelection = assembleField(data.featSelection, "feat_selection", data);
    
    final actionsId = ctx.childId(nodeId, "actions");
    final actions = actionsId != null ? Actions.assemble(ctx, actionsId) : null;

    final penaltiesId = ctx.childId(nodeId, "penalties");
    final penalties = penaltiesId != null ? Penalties.assemble(ctx, penaltiesId) : null;

    final stopCondsId = ctx.childId(nodeId, "stop_conds");
    final stopConds = stopCondsId != null ? StopConds.assemble(ctx, stopCondsId) : null;

    final optId = ctx.childId(nodeId, "opt");
    final opt = optId != null ? GeneticOpt.assemble(ctx, optId) : null;

    final globalMaxPositions = assembleField(data.globalMaxPositions, "global_max_positions", data);

    final entryIds = ctx.childIds(nodeId, "entry_pool");
    Map<String, dynamic> assembleEntry(id) => EntrySchema.assemble(ctx, id);
    final entryPool = entryIds.map(assembleEntry).toList();

    final entrySelection = assembleField(data.entrySelection, "entry_selection", data);

    final exitIds = ctx.childIds(nodeId, "exit_pool");
    Map<String, dynamic> assembleExit(id) => ExitSchema.assemble(ctx, id);
    final exitPool = exitIds.map(assembleExit).toList();

    final exitSelection = assembleField(data.exitSelection, "exit_selection", data);

    final result = <String, dynamic>{
      "base_net": baseNet,
      "feat_pool": featPool,
      "feat_selection": featSelection,
      "actions": actions,
      "penalties": penalties,
      "stop_conds": stopConds,
      "opt": opt,
      "global_max_positions": globalMaxPositions,
      "entry_pool": entryPool,
      "entry_selection": entrySelection,
      "exit_pool": exitPool,
      "exit_selection": exitSelection
      
    };
    if (actionsId != null) {
      result["actions"] = Actions.assemble(ctx, actionsId);
    }
    if (penaltiesId != null) {
      result["penalties"] = Penalties.assemble(ctx, penaltiesId);
    }
    if (stopCondsId != null) {
      result["stop_conds"] = StopConds.assemble(ctx, stopCondsId);
    }
    if (optId != null) {
      result["opt"] = GeneticOpt.assemble(ctx, optId);
    }
    return result;
  }

  static String flattenFeat(FlattenContext ctx, Map<String, dynamic> json) {
    final feature = json["feature"] as String;
    if (feature == "constant") {
      return Constant.flatten(ctx, json);
    }
    return RawReturns.flatten(ctx, json);
  }

  static Map<String, dynamic> assembleFeat(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId);
    if (node.data is Constant) {
      return Constant.assemble(ctx, nodeId);
    }
    return RawReturns.assemble(ctx, nodeId);
  }
}

class ExperimentGenerator extends NodeObject {
  String title;
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;

  @override
  NodeType get nodeType => NodeType.experimentGen;

  ExperimentGenerator({this.title = "", this.valSize = 0.0, this.testSize = 0.0, this.cvFolds = 0, this.foldSize = 0.0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "title": title = text;
      case "val_size": valSize = double.tryParse(text) ?? 0.0;
      case "test_size": testSize = double.tryParse(text) ?? 0.0;
      case "cv_folds": cvFolds = int.tryParse(text) ?? 0;
      case "fold_size": foldSize = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "title" => title,
      "val_size" => valSize.toString(),
      "test_size" => testSize.toString(),
      "cv_folds" => cvFolds.toString(),
      "fold_size" => foldSize.toString(),
      _ => ""
    };
  }

  static final nodeTypeToEmpty = <NodeType, NodeObject Function()>{
    NodeType.experimentGen: ExperimentGenerator.new,
    NodeType.backtestSchema: BacktestSchema.new,
    NodeType.strategyGen: Strategy.new,
    NodeType.networkGen: Network.new,
    NodeType.logicNet: LogicNet.new,
    NodeType.decisionNet: DecisionNet.new,
    NodeType.inputNode: InputNode.new,
    NodeType.gateNode: GateNode.new,
    NodeType.branchNode: BranchNode.new,
    NodeType.refNode: RefNode.new,
    NodeType.nodePtr: NodePtr.new,
    NodeType.constantFeature: Constant.new,
    NodeType.rawReturnsFeature: RawReturns.new,
    NodeType.actionsGen: Actions.new,
    NodeType.logicActions: LogicActions.new,
    NodeType.decisionActions: DecisionActions.new,
    NodeType.metaAction: MetaAction.new,
    NodeType.thresholdRange: ThresholdRange.new,
    NodeType.penaltiesGen: Penalties.new,
    NodeType.logicPenalties: LogicPenalties.new,
    NodeType.decisionPenalties: DecisionPenalties.new,
    NodeType.stopConds: StopConds.new,
    NodeType.geneticOpt: GeneticOpt.new,
    NodeType.entrySchema: EntrySchema.new,
    NodeType.exitSchema: ExitSchema.new
  };

  static List<Port> ports() {
    return outputPorts(["backtest_schema", "strategy"]);
  }

  static GraphData flatten(Map<String, dynamic> json) {
    final ctx = FlattenContext();
    final paramRefs = <String, String>{};

    final title = getField<String>(json, "title", "", paramRefs);
    final valSize = getField<double>(json, "val_size", 0.0, paramRefs, doubleFromJson);
    final testSize = getField<double>(json, "test_size", 0.0, paramRefs, doubleFromJson);
    final cvFolds = getField<int>(json, "cv_folds", 0, paramRefs);
    final foldSize = getField<double>(json, "fold_size", 0.0, paramRefs, doubleFromJson);

    final data = ExperimentGenerator(
      title: title,
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize,
      paramRefs: paramRefs
    );
    final rootId = ctx.addNode(data);

    final backtestSchemaJson = json["backtest_schema"] as Map<String, dynamic>?;
    if (backtestSchemaJson != null) {
      final backtestSchemaId = BacktestSchema.flatten(ctx, backtestSchemaJson);
      ctx.connect(rootId, "backtest_schema", backtestSchemaId);
    }

    final strategyJson = json["strategy"] as Map<String, dynamic>?;
    if (strategyJson != null) {
      final strategyId = Strategy.flatten(ctx, strategyJson);
      ctx.connect(rootId, "strategy", strategyId);
    }

    return GraphData(nodes: ctx.nodes, connections: ctx.connections);
  }

  static Map<String, dynamic> assemble(List<Node<NodeObject>> nodes, List<Connection> connections) {
    final ctx = AssembleContext(nodes: nodes, connections: connections);

    Node<NodeObject>? rootNode;
    for (final node in nodes) {
      if (node.data.nodeType == NodeType.experimentGen) {
        rootNode = node;
        break;
      }
    }

    if (rootNode == null) {
      throw Exception("Could not find Experiment node");
    }

    final data = rootNode.data as ExperimentGenerator;

    final title = assembleField(data.title, "title", data);
    final valSize = assembleField(data.valSize, "val_size", data);
    final testSize = assembleField(data.testSize, "test_size", data);
    final cvFolds = assembleField(data.cvFolds, "cv_folds", data);
    final foldSize = assembleField(data.foldSize, "fold_size", data);

    final backtestSchemaId = ctx.childId(rootNode.id, "backtest_schema");
    final backtestSchema = backtestSchemaId != null ? BacktestSchema.assemble(ctx, backtestSchemaId) : null;

    final strategyId = ctx.childId(rootNode.id, "strategy");
    final strategy = strategyId != null ? Strategy.assemble(ctx, strategyId) : null;

    return {
      "title": title,
      "val_size": valSize,
      "test_size": testSize,
      "cv_folds": cvFolds,
      "fold_size": foldSize,
      "backtest_schema": backtestSchema,
      "strategy": strategy
    };
  }
}
