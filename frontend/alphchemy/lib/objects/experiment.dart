import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class BacktestSchema extends NodeObject {
  int startOffset;
  double startBalance;
  int delay;

  @override
  String get nodeType => "backtest_schema";

  BacktestSchema({this.startOffset = 0, this.startBalance = 10000.0, this.delay = 1});

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
  String nodePtrId;
  double positionSize;
  int maxPositions;

  @override
  String get nodeType => "entry_schema";

  EntrySchema({
    this.nodePtrId = "",
    this.positionSize = 0.1,
    this.maxPositions = 1
  });

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
    final data = EntrySchema(
      nodePtrId: nodePtrId,
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
      "node_ptr": nodePtrId != null
          ? NodePtr.assemble(ctx, nodePtrId)
          : null,
      "position_size": assembleField(data.positionSize, "positionSize", data.paramRefs),
      "max_positions": assembleField(data.maxPositions, "maxPositions", data.paramRefs)
    };
  }
}

class ExitSchema extends NodeObject {
  String nodePtrId;
  List<int> entryIndices;
  double stopLoss;
  double takeProfit;
  int maxHoldTime;

  @override
  String get nodeType => "exit_schema";

  ExitSchema({this.nodePtrId = "", this.entryIndices = const [], this.stopLoss = 0.0, this.takeProfit = 0.0, this.maxHoldTime = 0});

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
    final entryIndices = intListOrDefault(json, "entry_indices", "entryIndices", const [], refs);
    final data = ExitSchema(
      nodePtrId: nodePtrId,
      entryIndices: entryIndices,
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
      "node_ptr": nodePtrId != null
          ? NodePtr.assemble(ctx, nodePtrId)
          : null,
      "entry_indices": assembleField(data.entryIndices, "entryIndices", data.paramRefs),
      "stop_loss": assembleField(data.stopLoss, "stopLoss", data.paramRefs),
      "take_profit": assembleField(data.takeProfit, "takeProfit", data.paramRefs),
      "max_hold_time": assembleField(data.maxHoldTime, "maxHoldTime", data.paramRefs)
    };
  }
}

class NetworkGen extends NodeObject {
  String type;
  String? logicNetId;
  String? decisionNetId;

  @override
  String get nodeType => "network_gen";

  NetworkGen({
    this.type = "logic",
    this.logicNetId,
    this.decisionNetId
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_net", "decision_net"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final type = stringOrDefault(json, "type", "type", "logic", refs);
    String? logicNetId;
    String? decisionNetId;
    final logicJson = json["logic_net"] as Map<String, dynamic>?;
    if (logicJson != null) {
      logicNetId = LogicNet.flatten(ctx, logicJson);
    }
    final decisionJson = json["decision_net"] as Map<String, dynamic>?;
    if (decisionJson != null) {
      decisionNetId = DecisionNet.flatten(ctx, decisionJson);
    }
    final data = NetworkGen(
      type: type,
      logicNetId: logicNetId,
      decisionNetId: decisionNetId
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    if (logicNetId != null) {
      ctx.connect(parentId, "out_logic_net", logicNetId);
    }
    if (decisionNetId != null) {
      ctx.connect(parentId, "out_decision_net", decisionNetId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as NetworkGen;
    final logicNetNodeId = ctx.childId(nodeId, "out_logic_net");
    final decisionNetNodeId = ctx.childId(nodeId, "out_decision_net");
    return {
      "type": assembleField(data.type, "type", data.paramRefs),
      "logic_net": logicNetNodeId != null
          ? LogicNet.assemble(ctx, logicNetNodeId)
          : null,
      "decision_net": decisionNetNodeId != null
          ? DecisionNet.assemble(ctx, decisionNetNodeId)
          : null
    };
  }
}

class PenaltiesGen extends NodeObject {
  String type;
  String? logicPenaltiesId;
  String? decisionPenaltiesId;

  @override
  String get nodeType => "penalties_gen";

  PenaltiesGen({
    this.type = "logic",
    this.logicPenaltiesId,
    this.decisionPenaltiesId
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_penalties", "decision_penalties"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final type = stringOrDefault(json, "type", "type", "logic", refs);
    String? logicPenaltiesId;
    String? decisionPenaltiesId;
    final logicJson = json["logic_penalties"] as Map<String, dynamic>?;
    if (logicJson != null) {
      logicPenaltiesId = LogicPenalties.flatten(ctx, logicJson);
    }
    final decisionJson = json["decision_penalties"] as Map<String, dynamic>?;
    if (decisionJson != null) {
      decisionPenaltiesId = DecisionPenalties.flatten(ctx, decisionJson);
    }
    final data = PenaltiesGen(
      type: type,
      logicPenaltiesId: logicPenaltiesId,
      decisionPenaltiesId: decisionPenaltiesId
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    if (logicPenaltiesId != null) {
      ctx.connect(parentId, "out_logic_penalties", logicPenaltiesId);
    }
    if (decisionPenaltiesId != null) {
      ctx.connect(parentId, "out_decision_penalties", decisionPenaltiesId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as PenaltiesGen;
    final logicId = ctx.childId(nodeId, "out_logic_penalties");
    final decisionId = ctx.childId(nodeId, "out_decision_penalties");
    return {
      "type": assembleField(data.type, "type", data.paramRefs),
      "logic_penalties": logicId != null
          ? LogicPenalties.assemble(ctx, logicId)
          : null,
      "decision_penalties": decisionId != null
          ? DecisionPenalties.assemble(ctx, decisionId)
          : null
    };
  }
}

class ActionsGen extends NodeObject {
  String type;
  String? logicActionsId;
  String? decisionActionsId;

  @override
  String get nodeType => "actions_gen";

  ActionsGen({
    this.type = "logic",
    this.logicActionsId,
    this.decisionActionsId
  });

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
    final data = ActionsGen(
      type: type,
      logicActionsId: logicActionsId,
      decisionActionsId: decisionActionsId
    );
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
  String baseNetId;
  List<String> featPoolIds;
  List<int> featSelection;
  String actionsId;
  String penaltiesId;
  String stopCondsId;
  String optId;
  List<String> entryPoolIds;
  List<int> entrySelection;
  List<String> exitPoolIds;
  List<int> exitSelection;

  @override
  String get nodeType => "strategy_gen";

  StrategyGen({
    this.baseNetId = "",
    this.featPoolIds = const [],
    this.featSelection = const [],
    this.actionsId = "",
    this.penaltiesId = "",
    this.stopCondsId = "",
    this.optId = "",
    this.entryPoolIds = const [],
    this.entrySelection = const [],
    this.exitPoolIds = const [],
    this.exitSelection = const []
  });

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
        featPoolIds.add(flattenFeature(ctx, map));
      }
    }
    final featSelection = intListOrDefault(json, "feat_selection", "featSelection", const [], refs);

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

    final entryPoolIds = <String>[];
    final rawEntryPool = json["entry_pool"] as List<dynamic>?;
    if (rawEntryPool != null) {
      for (final raw in rawEntryPool) {
        final map = raw as Map<String, dynamic>;
        entryPoolIds.add(EntrySchema.flatten(ctx, map));
      }
    }
    final entrySelection = intListOrDefault(json, "entry_selection", "entrySelection", const [], refs);

    final exitPoolIds = <String>[];
    final rawExitPool = json["exit_pool"] as List<dynamic>?;
    if (rawExitPool != null) {
      for (final raw in rawExitPool) {
        final map = raw as Map<String, dynamic>;
        exitPoolIds.add(ExitSchema.flatten(ctx, map));
      }
    }
    final exitSelection = intListOrDefault(json, "exit_selection", "exitSelection", const [], refs);

    final data = StrategyGen(
      baseNetId: baseNetId,
      featPoolIds: featPoolIds,
      featSelection: featSelection,
      actionsId: actionsId,
      penaltiesId: penaltiesId,
      stopCondsId: stopCondsId,
      optId: optId,
      entryPoolIds: entryPoolIds,
      entrySelection: entrySelection,
      exitPoolIds: exitPoolIds,
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
      return assembleFeature(ctx, id);
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
}

class ExperimentGenerator extends NodeObject {
  String title;
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  String backtestSchemaId;
  String strategyId;

  @override
  String get nodeType => "experiment_gen";

  ExperimentGenerator({
    this.title = "",
    this.valSize = 0.2,
    this.testSize = 0.1,
    this.cvFolds = 3,
    this.foldSize = 0.3,
    this.backtestSchemaId = "",
    this.strategyId = ""
  });

  static List<Port> ports() {
    return outputPorts(["backtest_schema", "strategy"]);
  }
}

// Widget classes

class BacktestSchemaContent extends StatelessWidget {
  final BacktestSchema data;

  const BacktestSchemaContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "startOffset",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "startOffset",
            value: data.startOffset.toString(),
            onChanged: (val) => data.startOffset = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "startBalance",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "startBal",
            value: data.startBalance.toString(),
            onChanged: (val) => data.startBalance = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "delay",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "delay",
            value: data.delay.toString(),
            onChanged: (val) => data.delay = int.tryParse(val) ?? 0
          )
        )
      ]
    );
  }
}

class EntrySchemaContent extends StatelessWidget {
  final EntrySchema data;

  const EntrySchemaContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "positionSize",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "posSize",
            value: data.positionSize.toString(),
            onChanged: (val) => data.positionSize = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "maxPositions",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "maxPos",
            value: data.maxPositions.toString(),
            onChanged: (val) => data.maxPositions = int.tryParse(val) ?? 0
          )
        )
      ]
    );
  }
}

class ExitSchemaContent extends StatelessWidget {
  final ExitSchema data;

  const ExitSchemaContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "entryIndices",
          paramType: ParamType.intListType,
          nodeData: data,
          child: NodeTextField(
            label: "entries",
            value: data.entryIndices.join(","),
            onChanged: (val) {
              data.entryIndices = parseIntList(val);
            }
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "stopLoss",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "stopLoss",
            value: data.stopLoss.toString(),
            onChanged: (val) => data.stopLoss = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "takeProfit",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "takeProfit",
            value: data.takeProfit.toString(),
            onChanged: (val) => data.takeProfit = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "maxHoldTime",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "maxHold",
            value: data.maxHoldTime.toString(),
            onChanged: (val) => data.maxHoldTime = int.tryParse(val) ?? 0
          )
        )
      ]
    );
  }
}

class NetworkGenContent extends StatelessWidget {
  final NetworkGen data;

  const NetworkGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ParamField(
      fieldKey: "type",
      paramType: ParamType.stringType,
      nodeData: data,
      child: NodeDropdown<String>(
        label: "type",
        value: data.type,
        options: ["logic", "decision"],
        labelFor: (val) => val,
        onChanged: (val) => data.type = val
      )
    );
  }
}

class PenaltiesGenContent extends StatelessWidget {
  final PenaltiesGen data;

  const PenaltiesGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ParamField(
      fieldKey: "type",
      paramType: ParamType.stringType,
      nodeData: data,
      child: NodeDropdown<String>(
        label: "type",
        value: data.type,
        options: ["logic", "decision"],
        labelFor: (val) => val,
        onChanged: (val) => data.type = val
      )
    );
  }
}

class ActionsGenContent extends StatelessWidget {
  final ActionsGen data;

  const ActionsGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ParamField(
      fieldKey: "type",
      paramType: ParamType.stringType,
      nodeData: data,
      child: NodeDropdown<String>(
        label: "type",
        value: data.type,
        options: ["logic", "decision"],
        labelFor: (val) => val,
        onChanged: (val) => data.type = val
      )
    );
  }
}

class StrategyGenContent extends StatelessWidget {
  final StrategyGen data;

  const StrategyGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "featSelection",
          paramType: ParamType.intListType,
          nodeData: data,
          child: NodeTextField(
            label: "featSel",
            value: data.featSelection.join(","),
            onChanged: (val) {
              data.featSelection = parseIntList(val);
            }
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "entrySelection",
          paramType: ParamType.intListType,
          nodeData: data,
          child: NodeTextField(
            label: "entrySel",
            value: data.entrySelection.join(","),
            onChanged: (val) {
              data.entrySelection = parseIntList(val);
            }
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "exitSelection",
          paramType: ParamType.intListType,
          nodeData: data,
          child: NodeTextField(
            label: "exitSel",
            value: data.exitSelection.join(","),
            onChanged: (val) {
              data.exitSelection = parseIntList(val);
            }
          )
        )
      ]
    );
  }
}

class ExperimentGenContent extends StatelessWidget {
  final ExperimentGenerator data;

  const ExperimentGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "title",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeTextField(
            label: "title",
            value: data.title,
            onChanged: (val) => data.title = val
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "valSize",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "valSize",
            value: data.valSize.toString(),
            onChanged: (val) => data.valSize = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "testSize",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "testSize",
            value: data.testSize.toString(),
            onChanged: (val) => data.testSize = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "cvFolds",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "cvFolds",
            value: data.cvFolds.toString(),
            onChanged: (val) => data.cvFolds = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "foldSize",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "foldSize",
            value: data.foldSize.toString(),
            onChanged: (val) => data.foldSize = double.tryParse(val) ?? 0
          )
        )
      ]
    );
  }
}
