import "package:alphchemy/model/generator/actions.dart";
import "package:alphchemy/model/generator/features.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/model/generator/optimizer.dart";
import "package:alphchemy/utils.dart";

class BacktestSchema extends NodeData {
  int startOffset;
  double startBalance;
  int delay;

  @override
  NodeType get nodeType => NodeType.backtestSchema;

  @override
  int get fieldCount => 3;

  BacktestSchema({
    this.startOffset = 0,
    this.startBalance = 0.0,
    this.delay = 0,
    super.paramRefs
  });

  factory BacktestSchema.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final startOffset = getField<int>(json, "start_offset", 0, paramRefs);
    final startBalance = getField<double>(json, "start_balance", 0.0, paramRefs, doubleFromJson);
    final delay = getField<int>(json, "delay", 0, paramRefs);

    return BacktestSchema(
      startOffset: startOffset,
      startBalance: startBalance,
      delay: delay,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "start_offset":
        startOffset = int.tryParse(text) ?? 0;
      case "start_balance":
        startBalance = double.tryParse(text) ?? 0.0;
      case "delay":
        delay = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "start_offset" => startOffset.toString(),
      "start_balance" => startBalance.toString(),
      "delay" => delay.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final startOffsetJson = assembleField("start_offset", startOffset);
    final startBalanceJson = assembleField("start_balance", startBalance);
    final delayJson = assembleField("delay", delay);

    return {
      "start_offset": startOffsetJson,
      "start_balance": startBalanceJson,
      "delay": delayJson
    };
  }
}

class EntrySchema extends NodeData {
  String id;
  double positionSize;
  int maxPositions;
  NodePtr? nodePtr;

  @override
  NodeType get nodeType => NodeType.entrySchema;

  @override
  int get fieldCount => 3;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "node_ptr", label: "Node Ptr", multi: false, allowedTypes: [NodeType.nodePtr])
    ];
  }

  EntrySchema({
    this.id = "",
    this.positionSize = 0.0,
    this.maxPositions = 0,
    this.nodePtr,
    super.paramRefs
  });

  factory EntrySchema.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final positionSize = getField<double>(json, "position_size", 0.0, paramRefs, doubleFromJson);
    final maxPositions = getField<int>(json, "max_positions", 0, paramRefs);
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    final nodePtr = nodePtrJson == null ? null : NodePtr.fromJson(nodePtrJson);

    return EntrySchema(
      id: id,
      positionSize: positionSize,
      maxPositions: maxPositions,
      nodePtr: nodePtr,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    if (slotKey != "node_ptr") return const [];
    return nodePtr == null ? const [] : [nodePtr!];
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    if (slotKey != "node_ptr") return false;
    nodePtr = child as NodePtr;
    return true;
  }

  @override
  bool removeDirectChild(String targetId) {
    if (nodePtr?.nodeId != targetId) return false;
    nodePtr = null;
    return true;
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "position_size":
        positionSize = double.tryParse(text) ?? 0.0;
      case "max_positions":
        maxPositions = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "position_size" => positionSize.toString(),
      "max_positions" => maxPositions.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final positionSizeJson = assembleField("position_size", positionSize);
    final maxPositionsJson = assembleField("max_positions", maxPositions);

    return {
      "id": idJson,
      "node_ptr": nodePtr?.toJson(),
      "position_size": positionSizeJson,
      "max_positions": maxPositionsJson
    };
  }
}

class ExitSchema extends NodeData {
  String id;
  List<String> entryIds;
  double stopLoss;
  double takeProfit;
  int maxHoldTime;
  NodePtr? nodePtr;

  @override
  NodeType get nodeType => NodeType.exitSchema;

  @override
  int get fieldCount => 5;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "node_ptr", label: "Node Ptr", multi: false, allowedTypes: [NodeType.nodePtr])
    ];
  }

  ExitSchema({
    this.id = "",
    this.entryIds = const [],
    this.stopLoss = 0.0,
    this.takeProfit = 0.0,
    this.maxHoldTime = 0,
    this.nodePtr,
    super.paramRefs
  });

  factory ExitSchema.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final entryIds = getField<List<String>>(json, "entry_ids", const [], paramRefs, listFromJson<String>);
    final stopLoss = getField<double>(json, "stop_loss", 0.0, paramRefs, doubleFromJson);
    final takeProfit = getField<double>(json, "take_profit", 0.0, paramRefs, doubleFromJson);
    final maxHoldTime = getField<int>(json, "max_hold_time", 0, paramRefs);
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    final nodePtr = nodePtrJson == null ? null : NodePtr.fromJson(nodePtrJson);

    return ExitSchema(
      id: id,
      entryIds: entryIds,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime,
      nodePtr: nodePtr,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    if (slotKey != "node_ptr") return const [];
    return nodePtr == null ? const [] : [nodePtr!];
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    if (slotKey != "node_ptr") return false;
    nodePtr = child as NodePtr;
    return true;
  }

  @override
  bool removeDirectChild(String targetId) {
    if (nodePtr?.nodeId != targetId) return false;
    nodePtr = null;
    return true;
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "entry_ids":
        entryIds = parseList(text);
      case "stop_loss":
        stopLoss = double.tryParse(text) ?? 0.0;
      case "take_profit":
        takeProfit = double.tryParse(text) ?? 0.0;
      case "max_hold_time":
        maxHoldTime = int.tryParse(text) ?? 0;
    }
  }

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

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final entryIdsJson = assembleField("entry_ids", entryIds);
    final stopLossJson = assembleField("stop_loss", stopLoss);
    final takeProfitJson = assembleField("take_profit", takeProfit);
    final maxHoldTimeJson = assembleField("max_hold_time", maxHoldTime);

    return {
      "id": idJson,
      "node_ptr": nodePtr?.toJson(),
      "entry_ids": entryIdsJson,
      "stop_loss": stopLossJson,
      "take_profit": takeProfitJson,
      "max_hold_time": maxHoldTimeJson
    };
  }
}

class Strategy extends NodeData {
  List<String> featSelection;
  int globalMaxPositions;
  List<String> entrySelection;
  List<String> exitSelection;
  Network? baseNet;
  List<NodeData> featPool;
  Actions? actions;
  Penalties? penalties;
  StopConds? stopConds;
  GeneticOpt? opt;
  List<EntrySchema> entryPool;
  List<ExitSchema> exitPool;

  @override
  NodeType get nodeType => NodeType.strategyGen;

  @override
  int get fieldCount => 4;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "base_net", label: "Base Net", multi: false, allowedTypes: [NodeType.networkGen]),
      ChildSlot(key: "feat_pool", label: "Feature", multi: true, allowedTypes: [NodeType.constantFeature, NodeType.rawReturnsFeature]),
      ChildSlot(key: "actions", label: "Actions", multi: false, allowedTypes: [NodeType.actionsGen]),
      ChildSlot(key: "penalties", label: "Penalties", multi: false, allowedTypes: [NodeType.penaltiesGen]),
      ChildSlot(key: "stop_conds", label: "Stop Conds", multi: false, allowedTypes: [NodeType.stopConds]),
      ChildSlot(key: "opt", label: "Optimizer", multi: false, allowedTypes: [NodeType.geneticOpt]),
      ChildSlot(key: "entry_pool", label: "Entry", multi: true, allowedTypes: [NodeType.entrySchema]),
      ChildSlot(key: "exit_pool", label: "Exit", multi: true, allowedTypes: [NodeType.exitSchema])
    ];
  }

  Strategy({
    this.featSelection = const [],
    this.globalMaxPositions = 1,
    this.entrySelection = const [],
    this.exitSelection = const [],
    this.baseNet,
    List<NodeData>? featPool,
    this.actions,
    this.penalties,
    this.stopConds,
    this.opt,
    List<EntrySchema>? entryPool,
    List<ExitSchema>? exitPool,
    super.paramRefs
  }) : featPool = featPool ?? <NodeData>[],
       entryPool = entryPool ?? <EntrySchema>[],
       exitPool = exitPool ?? <ExitSchema>[];

  factory Strategy.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final featSelection = getField<List<String>>(json, "feat_selection", const [], paramRefs, listFromJson<String>);
    final globalMaxPositions = getField<int>(json, "global_max_positions", 1, paramRefs);
    final entrySelection = getField<List<String>>(json, "entry_selection", const [], paramRefs, listFromJson<String>);
    final exitSelection = getField<List<String>>(json, "exit_selection", const [], paramRefs, listFromJson<String>);
    final baseNetJson = json["base_net"] as Map<String, dynamic>?;
    final actionsJson = json["actions"] as Map<String, dynamic>?;
    final penaltiesJson = json["penalties"] as Map<String, dynamic>?;
    final stopCondsJson = json["stop_conds"] as Map<String, dynamic>?;
    final optJson = json["opt"] as Map<String, dynamic>?;
    final featPool = <NodeData>[];
    final entryPool = <EntrySchema>[];
    final exitPool = <ExitSchema>[];
    final featPoolJson = json["feat_pool"] as List<dynamic>? ?? [];
    final entryPoolJson = json["entry_pool"] as List<dynamic>? ?? [];
    final exitPoolJson = json["exit_pool"] as List<dynamic>? ?? [];

    for (final featJson in featPoolJson) {
      final feat = Strategy.featureFromJson(featJson as Map<String, dynamic>);
      featPool.add(feat);
    }

    for (final entryJson in entryPoolJson) {
      final entry = EntrySchema.fromJson(entryJson as Map<String, dynamic>);
      entryPool.add(entry);
    }

    for (final exitJson in exitPoolJson) {
      final exit = ExitSchema.fromJson(exitJson as Map<String, dynamic>);
      exitPool.add(exit);
    }

    return Strategy(
      featSelection: featSelection,
      globalMaxPositions: globalMaxPositions,
      entrySelection: entrySelection,
      exitSelection: exitSelection,
      baseNet: baseNetJson == null ? null : Network.fromJson(baseNetJson),
      featPool: featPool,
      actions: actionsJson == null ? null : Actions.fromJson(actionsJson),
      penalties: penaltiesJson == null ? null : Penalties.fromJson(penaltiesJson),
      stopConds: stopCondsJson == null ? null : StopConds.fromJson(stopCondsJson),
      opt: optJson == null ? null : GeneticOpt.fromJson(optJson),
      entryPool: entryPool,
      exitPool: exitPool,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "base_net":
        return baseNet == null ? const [] : [baseNet!];
      case "feat_pool":
        return featPool;
      case "actions":
        return actions == null ? const [] : [actions!];
      case "penalties":
        return penalties == null ? const [] : [penalties!];
      case "stop_conds":
        return stopConds == null ? const [] : [stopConds!];
      case "opt":
        return opt == null ? const [] : [opt!];
      case "entry_pool":
        return entryPool;
      case "exit_pool":
        return exitPool;
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "base_net":
        baseNet = child as Network;
        return true;
      case "feat_pool":
        featPool.add(child);
        return true;
      case "actions":
        actions = child as Actions;
        return true;
      case "penalties":
        penalties = child as Penalties;
        return true;
      case "stop_conds":
        stopConds = child as StopConds;
        return true;
      case "opt":
        opt = child as GeneticOpt;
        return true;
      case "entry_pool":
        entryPool.add(child as EntrySchema);
        return true;
      case "exit_pool":
        exitPool.add(child as ExitSchema);
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (baseNet?.nodeId == targetId) {
      baseNet = null;
      return true;
    }

    if (removeChildFromList(featPool, targetId)) return true;

    if (actions?.nodeId == targetId) {
      actions = null;
      return true;
    }

    if (penalties?.nodeId == targetId) {
      penalties = null;
      return true;
    }

    if (stopConds?.nodeId == targetId) {
      stopConds = null;
      return true;
    }

    if (opt?.nodeId == targetId) {
      opt = null;
      return true;
    }

    if (removeChildFromList(entryPool, targetId)) return true;
    return removeChildFromList(exitPool, targetId);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "feat_selection":
        featSelection = parseList(text);
      case "global_max_positions":
        globalMaxPositions = int.tryParse(text) ?? 1;
      case "entry_selection":
        entrySelection = parseList(text);
      case "exit_selection":
        exitSelection = parseList(text);
    }
  }

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

  @override
  Map<String, dynamic> toJson() {
    final featPoolJson = featPool.map((feat) => feat.toJson()).toList();
    final entryPoolJson = entryPool.map((entry) => entry.toJson()).toList();
    final exitPoolJson = exitPool.map((exit) => exit.toJson()).toList();
    final featSelectionJson = assembleField("feat_selection", featSelection);
    final globalMaxPositionsJson = assembleField("global_max_positions", globalMaxPositions);
    final entrySelectionJson = assembleField("entry_selection", entrySelection);
    final exitSelectionJson = assembleField("exit_selection", exitSelection);

    return {
      "base_net": baseNet?.toJson(),
      "feat_pool": featPoolJson,
      "feat_selection": featSelectionJson,
      "actions": actions?.toJson(),
      "penalties": penalties?.toJson(),
      "stop_conds": stopConds?.toJson(),
      "opt": opt?.toJson(),
      "global_max_positions": globalMaxPositionsJson,
      "entry_pool": entryPoolJson,
      "entry_selection": entrySelectionJson,
      "exit_pool": exitPoolJson,
      "exit_selection": exitSelectionJson
    };
  }

  static NodeData featureFromJson(Map<String, dynamic> json) {
    final feature = json["feature"];

    if (feature == "constant") {
      return Constant.fromJson(json);
    }

    return RawReturns.fromJson(json);
  }
}

class ExperimentGenerator extends NodeData {
  String title;
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  BacktestSchema? backtestSchema;
  Strategy? strategy;

  @override
  NodeType get nodeType => NodeType.experimentGen;

  @override
  int get fieldCount => 5;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "backtest_schema", label: "Backtest", multi: false, allowedTypes: [NodeType.backtestSchema]),
      ChildSlot(key: "strategy", label: "Strategy", multi: false, allowedTypes: [NodeType.strategyGen])
    ];
  }

  ExperimentGenerator({
    this.title = "",
    this.valSize = 0.0,
    this.testSize = 0.0,
    this.cvFolds = 0,
    this.foldSize = 0.0,
    this.backtestSchema,
    this.strategy,
    super.paramRefs
  });

  factory ExperimentGenerator.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final title = getField<String>(json, "title", "", paramRefs);
    final valSize = getField<double>(json, "val_size", 0.0, paramRefs, doubleFromJson);
    final testSize = getField<double>(json, "test_size", 0.0, paramRefs, doubleFromJson);
    final cvFolds = getField<int>(json, "cv_folds", 0, paramRefs);
    final foldSize = getField<double>(json, "fold_size", 0.0, paramRefs, doubleFromJson);
    final backtestJson = json["backtest_schema"] as Map<String, dynamic>?;
    final strategyJson = json["strategy"] as Map<String, dynamic>?;

    return ExperimentGenerator(
      title: title,
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize,
      backtestSchema: backtestJson == null ? null : BacktestSchema.fromJson(backtestJson),
      strategy: strategyJson == null ? null : Strategy.fromJson(strategyJson),
      paramRefs: paramRefs
    );
  }

  static NodeData createEmptyNode(NodeType nodeType) {
    final factory = _emptyNodeFactories[nodeType];
    if (factory == null) {
      throw Exception("No factory for node type ${nodeType.value}");
    }
    return factory();
  }

  static final _emptyNodeFactories = <NodeType, NodeData Function()>{
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

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "backtest_schema":
        return backtestSchema == null ? const [] : [backtestSchema!];
      case "strategy":
        return strategy == null ? const [] : [strategy!];
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "backtest_schema":
        backtestSchema = child as BacktestSchema;
        return true;
      case "strategy":
        strategy = child as Strategy;
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (backtestSchema?.nodeId == targetId) {
      backtestSchema = null;
      return true;
    }

    if (strategy?.nodeId == targetId) {
      strategy = null;
      return true;
    }

    return false;
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "title":
        title = text;
      case "val_size":
        valSize = double.tryParse(text) ?? 0.0;
      case "test_size":
        testSize = double.tryParse(text) ?? 0.0;
      case "cv_folds":
        cvFolds = int.tryParse(text) ?? 0;
      case "fold_size":
        foldSize = double.tryParse(text) ?? 0.0;
    }
  }

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

  @override
  Map<String, dynamic> toJson() {
    final titleJson = assembleField("title", title);
    final valSizeJson = assembleField("val_size", valSize);
    final testSizeJson = assembleField("test_size", testSize);
    final cvFoldsJson = assembleField("cv_folds", cvFolds);
    final foldSizeJson = assembleField("fold_size", foldSize);

    return {
      "title": titleJson,
      "val_size": valSizeJson,
      "test_size": testSizeJson,
      "cv_folds": cvFoldsJson,
      "fold_size": foldSizeJson,
      "backtest_schema": backtestSchema?.toJson(),
      "strategy": strategy?.toJson()
    };
  }
}
