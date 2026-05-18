import "package:alphchemy/model/experiment/actions.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/network.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/experiment/optimizer.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart" hide Actions;

class BacktestSchema extends NodeData {
  int startOffset;
  double startBalance;
  int delay;

  @override
  NodeType get nodeType => NodeType.backtestSchema;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Start Offset", field: "start_offset"),
    NodeTextField(label: "Start Balance", field: "start_balance"),
    NodeTextField(label: "Delay", field: "delay")
  ];

  BacktestSchema({this.startOffset = 0, this.startBalance = 0.0, this.delay = 0});

  factory BacktestSchema.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final startOffset = getField<int>(json, "start_offset", 0);
    final startBalance = getField<double>(json, "start_balance", 0.0, doubleFromJson);
    final delay = getField<int>(json, "delay", 0);

    final node = BacktestSchema(startOffset: startOffset, startBalance: startBalance, delay: delay);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "start_offset":
        startOffset = int.tryParse(text) ?? 0;
      case "start_balance":
        startBalance = double.tryParse(text) ?? 0.0;
      case "delay":
        delay = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "start_offset" => startOffset.toString(),
      "start_balance" => startBalance.toString(),
      "delay" => delay.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "node_id": nodeId,
      "start_offset": startOffset,
      "start_balance": startBalance,
      "delay": delay
    };
  }

  @override
  NodeData copy() => BacktestSchema.fromJson(toJson());
}

class EntrySchema extends NodeData {
  String id;
  double positionSize;
  int maxPositions;
  NodePtr? nodePtr;

  @override
  NodeType get nodeType => NodeType.entrySchema;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "ID", field: "id"),
    NodeTextField(label: "Position Size", field: "position_size"),
    NodeTextField(label: "Max Positions", field: "max_positions")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "node_ptr", label: "Node Pointer", isMulti: false, allowedTypes: [NodeType.nodePtr])
    ];
  }

  EntrySchema({this.id = "", this.positionSize = 0.0, this.maxPositions = 0, this.nodePtr});

  factory EntrySchema.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id", "");
    final positionSize = getField<double>(json, "position_size", 0.0, doubleFromJson);
    final maxPositions = getField<int>(json, "max_positions", 0);
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    final nodePtr = nodePtrJson == null ? null : NodePtr.fromJson(nodePtrJson);

    final node = EntrySchema(
      id: id,
      positionSize: positionSize,
      maxPositions: maxPositions,
      nodePtr: nodePtr
    );
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    if (field != "node_ptr") return const [];
    return nodePtr == null ? const [] : [nodePtr!];
  }

  @override
  bool attachChild(String field, NodeData child) {
    if (field != "node_ptr") return false;
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
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "position_size":
        positionSize = double.tryParse(text) ?? 0.0;
      case "max_positions":
        maxPositions = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "id" => id,
      "position_size" => positionSize.toString(),
      "max_positions" => maxPositions.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "node_id": nodeId,
      "id": id,
      "node_ptr": nodePtr?.toJson(),
      "position_size": positionSize,
      "max_positions": maxPositions
    };
  }

  @override
  NodeData copy() => EntrySchema.fromJson(toJson());
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
  List<Widget> get fields => const [
    NodeTextField(label: "ID", field: "id"),
    NodeTextField(label: "Entry Schemas", field: "entry_ids"),
    NodeTextField(label: "Stop Loss", field: "stop_loss"),
    NodeTextField(label: "Take Profit", field: "take_profit"),
    NodeTextField(label: "Max Holding Time", field: "max_hold_time")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "node_ptr", label: "Node Pointer", isMulti: false, allowedTypes: [NodeType.nodePtr])
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
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id", "");
    final entryIds = getField<List<String>>(json, "entry_ids", const [], listFromJson<String>);
    final stopLoss = getField<double>(json, "stop_loss", 0.0, doubleFromJson);
    final takeProfit = getField<double>(json, "take_profit", 0.0, doubleFromJson);
    final maxHoldTime = getField<int>(json, "max_hold_time", 0);
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>?;
    final nodePtr = nodePtrJson == null ? null : NodePtr.fromJson(nodePtrJson);

    final node = ExitSchema(
      id: id,
      entryIds: entryIds,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime,
      nodePtr: nodePtr
    );
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    if (field != "node_ptr") return const [];
    return nodePtr == null ? const [] : [nodePtr!];
  }

  @override
  bool attachChild(String field, NodeData child) {
    if (field != "node_ptr") return false;
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
  void updateField(String field, String text) {
    switch (field) {
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
  String formatField(String field) {
    return switch (field) {
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
      "node_id": nodeId,
      "id": id,
      "node_ptr": nodePtr?.toJson(),
      "entry_ids": entryIds,
      "stop_loss": stopLoss,
      "take_profit": takeProfit,
      "max_hold_time": maxHoldTime
    };
  }

  @override
  NodeData copy() => ExitSchema.fromJson(toJson());
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
  List<Widget> get fields => const [
    NodeTextField(label: "Global Max Positions", field: "global_max_positions")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "base_net", label: "Base Network", isMulti: false, allowedTypes: [NodeType.logicNet, NodeType.decisionNet]),
      ChildSlot(field: "feats", label: "Features", isMulti: true, allowedTypes: [
        NodeType.constant,
        NodeType.rawReturns,
        NodeType.normalizedSma,
        NodeType.normalizedEma,
        NodeType.normalizedMacd,
        NodeType.rsi,
        NodeType.normalizedBb,
        NodeType.stochastic,
        NodeType.atr,
        NodeType.roc,
        NodeType.normalizedDc
      ]),
      ChildSlot(field: "actions", label: "Actions", isMulti: false, allowedTypes: [NodeType.logicActions, NodeType.decisionActions]),
      ChildSlot(field: "penalties", label: "Penalties", isMulti: false, allowedTypes: [NodeType.logicPenalties, NodeType.decisionPenalties]),
      ChildSlot(field: "stop_conds", label: "Stop Conditions", isMulti: false, allowedTypes: [NodeType.stopConds]),
      ChildSlot(field: "opt", label: "Optimizer", isMulti: false, allowedTypes: [NodeType.geneticOpt]),
      ChildSlot(field: "entry_schemas", label: "Entry", isMulti: true, allowedTypes: [NodeType.entrySchema]),
      ChildSlot(field: "exit_schemas", label: "Exit", isMulti: true, allowedTypes: [NodeType.exitSchema])
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
    final nodeId = json["node_id"];
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

    final node = Strategy(
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
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    switch (field) {
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
  bool attachChild(String field, NodeData child) {
    switch (field) {
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
  void updateField(String field, String text) {
    switch (field) {
      case "global_max_positions":
        globalMaxPositions = int.tryParse(text) ?? 1;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
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
      "node_id": nodeId,
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

  @override
  NodeData copy() => Strategy.fromJson(toJson());

  static NodeData featureFromJson(Map<String, dynamic> json) {
    final feature = json["feature"];

    return switch (feature) {
      "constant" => Constant.fromJson(json),
      "raw_returns" => RawReturns.fromJson(json),
      "normalized_sma" => NormalizedSMA.fromJson(json),
      "normalized_ema" => NormalizedEMA.fromJson(json),
      "normalized_macd" => NormalizedMACD.fromJson(json),
      "rsi" => RSI.fromJson(json),
      "normalized_bb" => NormalizedBB.fromJson(json),
      "stochastic" => Stochastic.fromJson(json),
      "normalized_atr" => NormalizedATR.fromJson(json),
      "roc" => ROC.fromJson(json),
      "normalized_dc" => NormalizedDC.fromJson(json),
      _ => throw Exception("Invalid feature: $feature")
    };
  }
}

class Experiment extends NodeData {
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  double startTimestamp;
  double endTimestamp;
  BacktestSchema? backtestSchema;
  Strategy? strategy;

  @override
  NodeType get nodeType => NodeType.experiment;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Validation Size", field: "val_size"),
    NodeTextField(label: "Test Size", field: "test_size"),
    NodeTextField(label: "CV Folds", field: "cv_folds"),
    NodeTextField(label: "Fold Size", field: "fold_size"),
    NodeDateTimeField(label: "Start Timestamp", field: "start_timestamp"),
    NodeDateTimeField(label: "End Timestamp", field: "end_timestamp")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "backtest_schema", label: "Backtest Schema", isMulti: false, allowedTypes: [NodeType.backtestSchema]),
      ChildSlot(field: "strategy", label: "Strategy", isMulti: false, allowedTypes: [NodeType.strategy])
    ];
  }

  Experiment({this.valSize = 0.0, this.testSize = 0.0, this.cvFolds = 0, this.foldSize = 0.0, this.startTimestamp = 0.0, this.endTimestamp = 0.0, this.backtestSchema, this.strategy});

  factory Experiment.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final valSize = getField<double>(json, "val_size", 0.0, doubleFromJson);
    final testSize = getField<double>(json, "test_size", 0.0, doubleFromJson);
    final cvFolds = getField<int>(json, "cv_folds", 0);
    final foldSize = getField<double>(json, "fold_size", 0.0, doubleFromJson);
    final startTimestamp = getField<double>(json, "start_timestamp", 0.0, doubleFromJson);
    final endTimestamp = getField<double>(json, "end_timestamp", 0.0, doubleFromJson);
    final backtestJson = json["backtest_schema"] as Map<String, dynamic>?;
    final strategyJson = json["strategy"] as Map<String, dynamic>?;

    final node = Experiment(
      valSize: valSize,
      testSize: testSize,
      cvFolds: cvFolds,
      foldSize: foldSize,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      backtestSchema: backtestJson == null ? null : BacktestSchema.fromJson(backtestJson),
      strategy: strategyJson == null ? null : Strategy.fromJson(strategyJson)
    );
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    switch (field) {
      case "backtest_schema":
        return backtestSchema == null ? const [] : [backtestSchema!];
      case "strategy":
        return strategy == null ? const [] : [strategy!];
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String field, NodeData child) {
    switch (field) {
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
  void updateField(String field, String text) {
    switch (field) {
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
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "start_timestamp":
        startTimestamp = value as double;
      case "end_timestamp":
        endTimestamp = value as double;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "val_size" => valSize.toString(),
      "test_size" => testSize.toString(),
      "cv_folds" => cvFolds.toString(),
      "fold_size" => foldSize.toString(),
      "start_timestamp" => timestampToIso(startTimestamp),
      "end_timestamp" => timestampToIso(endTimestamp),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "node_id": nodeId,
      "val_size": valSize,
      "test_size": testSize,
      "cv_folds": cvFolds,
      "fold_size": foldSize,
      "start_timestamp": startTimestamp,
      "end_timestamp": endTimestamp,
      "backtest_schema": backtestSchema?.toJson(),
      "strategy": strategy?.toJson()
    };
  }

  @override
  NodeData copy() => Experiment.fromJson(toJson());
}
