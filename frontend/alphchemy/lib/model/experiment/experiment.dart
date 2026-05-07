import "package:alphchemy/model/experiment/actions.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/network.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/experiment/optimizer.dart";
import "package:alphchemy/utils.dart";

class BacktestSchema extends NodeData {
  int startOffset;
  double startBalance;
  int delay;

  @override
  NodeType get nodeType => NodeType.backtestSchema;

  @override
  int get fieldCount => 3;

  BacktestSchema({this.startOffset = 0, this.startBalance = 0.0, this.delay = 0});

  factory BacktestSchema.fromJson(Map<String, dynamic> json) {
    final startOffset = getField<int>(json, "start_offset", 0);
    final startBalance = getField<double>(json, "start_balance", 0.0, doubleFromJson);
    final delay = getField<int>(json, "delay", 0);

    return BacktestSchema(startOffset: startOffset, startBalance: startBalance, delay: delay);
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
    return {
      "start_offset": startOffset,
      "start_balance": startBalance,
      "delay": delay
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

  EntrySchema({this.id = "", this.positionSize = 0.0, this.maxPositions = 0, this.nodePtr});

  factory EntrySchema.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final positionSize = getField<double>(json, "position_size", 0.0, doubleFromJson);
    final maxPositions = getField<int>(json, "max_positions", 0);
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    final nodePtr = nodePtrJson == null ? null : NodePtr.fromJson(nodePtrJson);

    return EntrySchema(
      id: id,
      positionSize: positionSize,
      maxPositions: maxPositions,
      nodePtr: nodePtr
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
    return {
      "id": id,
      "node_ptr": nodePtr?.toJson(),
      "position_size": positionSize,
      "max_positions": maxPositions
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
    this.nodePtr
  });

  factory ExitSchema.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final entryIds = getField<List<String>>(json, "entry_ids", const [], listFromJson<String>);
    final stopLoss = getField<double>(json, "stop_loss", 0.0, doubleFromJson);
    final takeProfit = getField<double>(json, "take_profit", 0.0, doubleFromJson);
    final maxHoldTime = getField<int>(json, "max_hold_time", 0);
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    final nodePtr = nodePtrJson == null ? null : NodePtr.fromJson(nodePtrJson);

    return ExitSchema(
      id: id,
      entryIds: entryIds,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime,
      nodePtr: nodePtr
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
    return {
      "id": id,
      "node_ptr": nodePtr?.toJson(),
      "entry_ids": entryIds,
      "stop_loss": stopLoss,
      "take_profit": takeProfit,
      "max_hold_time": maxHoldTime
    };
  }
}

class Strategy extends NodeData {
  int globalMaxPositions;
  Network? baseNet;
  List<NodeData> feats;
  Actions? actions;
  Penalties? penalties;
  StopConds? stopConds;
  GeneticOpt? opt;
  List<EntrySchema> entrySchemas;
  List<ExitSchema> exitSchemas;

  @override
  NodeType get nodeType => NodeType.strategy;

  @override
  int get fieldCount => 1;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "base_net", label: "Base Net", multi: false, allowedTypes: [NodeType.network]),
      ChildSlot(key: "feats", label: "Feature", multi: true, allowedTypes: [
        NodeType.constantFeature,
        NodeType.rawReturnsFeature,
        NodeType.smaFeature,
        NodeType.emaFeature,
        NodeType.macdFeature,
        NodeType.rsiFeature,
        NodeType.bollingerBandsFeature,
        NodeType.stochasticFeature,
        NodeType.atrFeature,
        NodeType.rocFeature,
        NodeType.momentumFeature,
        NodeType.donchianChannelFeature,
        NodeType.cciFeature
      ]),
      ChildSlot(key: "actions", label: "Actions", multi: false, allowedTypes: [NodeType.actions]),
      ChildSlot(key: "penalties", label: "Penalties", multi: false, allowedTypes: [NodeType.penalties]),
      ChildSlot(key: "stop_conds", label: "Stop Conds", multi: false, allowedTypes: [NodeType.stopConds]),
      ChildSlot(key: "opt", label: "Optimizer", multi: false, allowedTypes: [NodeType.geneticOpt]),
      ChildSlot(key: "entry_schemas", label: "Entry", multi: true, allowedTypes: [NodeType.entrySchema]),
      ChildSlot(key: "exit_schemas", label: "Exit", multi: true, allowedTypes: [NodeType.exitSchema])
    ];
  }

  Strategy({
    this.globalMaxPositions = 1,
    this.baseNet,
    List<NodeData>? feats,
    this.actions,
    this.penalties,
    this.stopConds,
    this.opt,
    List<EntrySchema>? entrySchemas,
    List<ExitSchema>? exitSchemas
  }) : feats = feats ?? <NodeData>[],
       entrySchemas = entrySchemas ?? <EntrySchema>[],
       exitSchemas = exitSchemas ?? <ExitSchema>[];

  factory Strategy.fromJson(Map<String, dynamic> json) {
    final globalMaxPositions = getField<int>(json, "global_max_positions", 1);
    final baseNetJson = json["base_net"] as Map<String, dynamic>?;
    final actionsJson = json["actions"] as Map<String, dynamic>?;
    final penaltiesJson = json["penalties"] as Map<String, dynamic>?;
    final stopCondsJson = json["stop_conds"] as Map<String, dynamic>?;
    final optJson = json["opt"] as Map<String, dynamic>?;
    final feats = <NodeData>[];
    final entrySchemas = <EntrySchema>[];
    final exitSchemas = <ExitSchema>[];
    final featsJson = json["feats"] as List<dynamic>? ?? [];
    final entrySchemasJson = json["entry_schemas"] as List<dynamic>? ?? [];
    final exitSchemasJson = json["exit_schemas"] as List<dynamic>? ?? [];

    for (final featJson in featsJson) {
      final feat = Strategy.featureFromJson(featJson as Map<String, dynamic>);
      feats.add(feat);
    }

    for (final entryJson in entrySchemasJson) {
      final entry = EntrySchema.fromJson(entryJson as Map<String, dynamic>);
      entrySchemas.add(entry);
    }

    for (final exitJson in exitSchemasJson) {
      final exit = ExitSchema.fromJson(exitJson as Map<String, dynamic>);
      exitSchemas.add(exit);
    }

    return Strategy(
      globalMaxPositions: globalMaxPositions,
      baseNet: baseNetJson == null ? null : Network.fromJson(baseNetJson),
      feats: feats,
      actions: actionsJson == null ? null : Actions.fromJson(actionsJson),
      penalties: penaltiesJson == null ? null : Penalties.fromJson(penaltiesJson),
      stopConds: stopCondsJson == null ? null : StopConds.fromJson(stopCondsJson),
      opt: optJson == null ? null : GeneticOpt.fromJson(optJson),
      entrySchemas: entrySchemas,
      exitSchemas: exitSchemas
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "base_net":
        return baseNet == null ? const [] : [baseNet!];
      case "feats":
        return feats;
      case "actions":
        return actions == null ? const [] : [actions!];
      case "penalties":
        return penalties == null ? const [] : [penalties!];
      case "stop_conds":
        return stopConds == null ? const [] : [stopConds!];
      case "opt":
        return opt == null ? const [] : [opt!];
      case "entry_schemas":
        return entrySchemas;
      case "exit_schemas":
        return exitSchemas;
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
      case "feats":
        feats.add(child);
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
      case "entry_schemas":
        entrySchemas.add(child as EntrySchema);
        return true;
      case "exit_schemas":
        exitSchemas.add(child as ExitSchema);
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

    if (removeChildFromList(feats, targetId)) return true;

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

    if (removeChildFromList(entrySchemas, targetId)) return true;
    return removeChildFromList(exitSchemas, targetId);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "global_max_positions":
        globalMaxPositions = int.tryParse(text) ?? 1;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "global_max_positions" => globalMaxPositions.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final featsJson = feats.map((feat) => feat.toJson()).toList();
    final entrySchemasJson = entrySchemas.map((entry) => entry.toJson()).toList();
    final exitSchemasJson = exitSchemas.map((exit) => exit.toJson()).toList();

    return {
      "base_net": baseNet?.toJson(),
      "feats": featsJson,
      "actions": actions?.toJson(),
      "penalties": penalties?.toJson(),
      "stop_conds": stopConds?.toJson(),
      "opt": opt?.toJson(),
      "global_max_positions": globalMaxPositions,
      "entry_schemas": entrySchemasJson,
      "exit_schemas": exitSchemasJson
    };
  }

  static NodeData featureFromJson(Map<String, dynamic> json) {
    final feature = json["feature"];

    return switch (feature) {
      "constant" => Constant.fromJson(json),
      "raw_returns" => RawReturns.fromJson(json),
      "sma" => Sma.fromJson(json),
      "ema" => Ema.fromJson(json),
      "macd" => Macd.fromJson(json),
      "rsi" => Rsi.fromJson(json),
      "bollinger_bands" => BollingerBands.fromJson(json),
      "stochastic" => Stochastic.fromJson(json),
      "atr" => Atr.fromJson(json),
      "roc" => Roc.fromJson(json),
      "momentum" => Momentum.fromJson(json),
      "donchian_channel" => DonchianChannel.fromJson(json),
      "cci" => Cci.fromJson(json),
      _ => throw Exception("Invalid feature: $feature")
    };
  }
}

class Experiment extends NodeData {
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  BacktestSchema? backtestSchema;
  Strategy? strategy;

  @override
  NodeType get nodeType => NodeType.experiment;

  @override
  int get fieldCount => 4;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "backtest_schema", label: "Backtest", multi: false, allowedTypes: [NodeType.backtestSchema]),
      ChildSlot(key: "strategy", label: "Strategy", multi: false, allowedTypes: [NodeType.strategy])
    ];
  }

  Experiment({
    this.valSize = 0.0,
    this.testSize = 0.0,
    this.cvFolds = 0,
    this.foldSize = 0.0,
    this.backtestSchema,
    this.strategy
  });

  factory Experiment.fromJson(Map<String, dynamic> json) {
    final valSize = getField<double>(json, "val_size", 0.0, doubleFromJson);
    final testSize = getField<double>(json, "test_size", 0.0, doubleFromJson);
    final cvFolds = getField<int>(json, "cv_folds", 0);
    final foldSize = getField<double>(json, "fold_size", 0.0, doubleFromJson);
    final backtestJson = json["backtest_schema"] as Map<String, dynamic>?;
    final strategyJson = json["strategy"] as Map<String, dynamic>?;

    return Experiment(
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize,
      backtestSchema: backtestJson == null ? null : BacktestSchema.fromJson(backtestJson),
      strategy: strategyJson == null ? null : Strategy.fromJson(strategyJson)
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
    NodeType.experiment: Experiment.new,
    NodeType.backtestSchema: BacktestSchema.new,
    NodeType.strategy: Strategy.new,
    NodeType.network: Network.new,
    NodeType.logicNet: LogicNet.new,
    NodeType.decisionNet: DecisionNet.new,
    NodeType.inputNode: InputNode.new,
    NodeType.gateNode: GateNode.new,
    NodeType.branchNode: BranchNode.new,
    NodeType.refNode: RefNode.new,
    NodeType.nodePtr: NodePtr.new,
    NodeType.constantFeature: Constant.new,
    NodeType.rawReturnsFeature: RawReturns.new,
    NodeType.smaFeature: Sma.new,
    NodeType.emaFeature: Ema.new,
    NodeType.macdFeature: Macd.new,
    NodeType.rsiFeature: Rsi.new,
    NodeType.bollingerBandsFeature: BollingerBands.new,
    NodeType.stochasticFeature: Stochastic.new,
    NodeType.atrFeature: Atr.new,
    NodeType.rocFeature: Roc.new,
    NodeType.momentumFeature: Momentum.new,
    NodeType.donchianChannelFeature: DonchianChannel.new,
    NodeType.cciFeature: Cci.new,
    NodeType.actions: Actions.new,
    NodeType.logicActions: LogicActions.new,
    NodeType.decisionActions: DecisionActions.new,
    NodeType.metaAction: MetaAction.new,
    NodeType.thresholdRange: ThresholdRange.new,
    NodeType.penalties: Penalties.new,
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
      "val_size" => valSize.toString(),
      "test_size" => testSize.toString(),
      "cv_folds" => cvFolds.toString(),
      "fold_size" => foldSize.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "val_size": valSize,
      "test_size": testSize,
      "cv_folds": cvFolds,
      "fold_size": foldSize,
      "backtest_schema": backtestSchema?.toJson(),
      "strategy": strategy?.toJson()
    };
  }
}
