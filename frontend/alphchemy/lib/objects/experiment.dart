import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class BacktestSchema extends NodeObject {
  int startOffset;
  double startBalance;
  int delay;

  @override
  String get nodeType => "backtest_schema";

  BacktestSchema({required this.startOffset, required this.startBalance, required this.delay});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final data = BacktestSchema(
      startOffset: json["start_offset"] as int,
      startBalance: doubleFromJson(json["start_balance"]),
      delay: json["delay"] as int
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as BacktestSchema;
    return {
      "start_offset": data.startOffset,
      "start_balance": data.startBalance,
      "delay": data.delay
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
    required this.nodePtrId,
    required this.positionSize,
    required this.maxPositions
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["node_ptr"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>;
    final nodePtrId = NodePtr.flatten(ctx, nodePtrJson);
    final positionSize = doubleFromJson(json["position_size"]);
    final maxPositions = json["max_positions"] as int;
    final data = EntrySchema(
      nodePtrId: nodePtrId,
      positionSize: positionSize,
      maxPositions: maxPositions
    );
    final parentId = ctx.addNode(data);
    ctx.connect(parentId, "out_node_ptr", nodePtrId);
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final nodePtrId = ctx.childId(nodeId, "out_node_ptr")!;
    final node = ctx.findNode(nodeId)!;
    final data = node.data as EntrySchema;
    return {
      "node_ptr": NodePtr.assemble(ctx, nodePtrId),
      "position_size": data.positionSize,
      "max_positions": data.maxPositions
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

  ExitSchema({required this.nodePtrId, required this.entryIndices, required this.stopLoss, required this.takeProfit, required this.maxHoldTime});

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["node_ptr"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final nodePtrJson = json["node_ptr"] as Map<String, dynamic>;
    final nodePtrId = NodePtr.flatten(ctx, nodePtrJson);
    final rawIndices = json["entry_indices"] as List<dynamic>;
    final entryIndices = List<int>.from(rawIndices);
    final stopLoss = doubleFromJson(json["stop_loss"]);
    final takeProfit = doubleFromJson(json["take_profit"]);
    final maxHoldTime = json["max_hold_time"] as int;
    final data = ExitSchema(
      nodePtrId: nodePtrId,
      entryIndices: entryIndices,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      maxHoldTime: maxHoldTime
    );
    final parentId = ctx.addNode(data);
    ctx.connect(parentId, "out_node_ptr", nodePtrId);
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final nodePtrId = ctx.childId(nodeId, "out_node_ptr")!;
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ExitSchema;
    return {
      "node_ptr": NodePtr.assemble(ctx, nodePtrId),
      "entry_indices": data.entryIndices,
      "stop_loss": data.stopLoss,
      "take_profit": data.takeProfit,
      "max_hold_time": data.maxHoldTime
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
    required this.type,
    required this.logicNetId,
    required this.decisionNetId
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_net", "decision_net"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"] as String;
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
      "type": data.type,
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
    required this.type,
    required this.logicPenaltiesId,
    required this.decisionPenaltiesId
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_penalties", "decision_penalties"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"] as String;
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
      "type": data.type,
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
    required this.type,
    required this.logicActionsId,
    required this.decisionActionsId
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["logic_actions", "decision_actions"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"] as String;
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
      "type": data.type,
      "logic_actions": logicId != null
          ? LogicActions.assemble(ctx, logicId)
          : null,
      "decision_actions": decisionId != null
          ? DecisionActions.assemble(ctx, decisionId)
          : null
    };
  }
}

class Strategy extends NodeObject {
  String baseNetId;
  List<String> featIds;
  String actionsId;
  String penaltiesId;
  String stopCondsId;
  String optId;
  List<String> entrySchemaIds;
  List<String> exitSchemaIds;

  @override
  String get nodeType => "strategy";

  Strategy({
    required this.baseNetId,
    required this.featIds,
    required this.actionsId,
    required this.penaltiesId,
    required this.stopCondsId,
    required this.optId,
    required this.entrySchemaIds,
    required this.exitSchemaIds
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts([
        "base_net",
        "feats",
        "actions",
        "penalties",
        "stop_conds",
        "opt",
        "entry_schemas",
        "exit_schemas"
      ])
    ];
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
    required this.baseNetId,
    required this.featPoolIds,
    required this.featSelection,
    required this.actionsId,
    required this.penaltiesId,
    required this.stopCondsId,
    required this.optId,
    required this.entryPoolIds,
    required this.entrySelection,
    required this.exitPoolIds,
    required this.exitSelection
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
    final baseNetJson = json["base_net"] as Map<String, dynamic>;
    final baseNetId = NetworkGen.flatten(ctx, baseNetJson);

    final rawFeatPool = json["feat_pool"] as List<dynamic>;
    final featPoolIds = <String>[];
    for (final raw in rawFeatPool) {
      final map = raw as Map<String, dynamic>;
      final id = flattenFeature(ctx, map);
      featPoolIds.add(id);
    }
    final rawFeatSelection = json["feat_selection"] as List<dynamic>;
    final featSelection = List<int>.from(rawFeatSelection);

    final actionsJson = json["actions"] as Map<String, dynamic>;
    final actionsId = ActionsGen.flatten(ctx, actionsJson);

    final penaltiesJson = json["penalties"] as Map<String, dynamic>;
    final penaltiesId = PenaltiesGen.flatten(ctx, penaltiesJson);

    final stopCondsJson = json["stop_conds"] as Map<String, dynamic>;
    final stopCondsId = StopConds.flatten(ctx, stopCondsJson);

    final optJson = json["opt"] as Map<String, dynamic>;
    final optId = GeneticOpt.flatten(ctx, optJson);

    final rawEntryPool = json["entry_pool"] as List<dynamic>;
    final entryPoolIds = <String>[];
    for (final raw in rawEntryPool) {
      final map = raw as Map<String, dynamic>;
      final id = EntrySchema.flatten(ctx, map);
      entryPoolIds.add(id);
    }
    final rawEntrySelection = json["entry_selection"] as List<dynamic>;
    final entrySelection = List<int>.from(rawEntrySelection);

    final rawExitPool = json["exit_pool"] as List<dynamic>;
    final exitPoolIds = <String>[];
    for (final raw in rawExitPool) {
      final map = raw as Map<String, dynamic>;
      final id = ExitSchema.flatten(ctx, map);
      exitPoolIds.add(id);
    }
    final rawExitSelection = json["exit_selection"] as List<dynamic>;
    final exitSelection = List<int>.from(rawExitSelection);

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
    final parentId = ctx.addNode(data);
    ctx.connect(parentId, "out_base_net", baseNetId);
    for (final childId in featPoolIds) {
      ctx.connect(parentId, "out_feat_pool", childId);
    }
    ctx.connect(parentId, "out_actions", actionsId);
    ctx.connect(parentId, "out_penalties", penaltiesId);
    ctx.connect(parentId, "out_stop_conds", stopCondsId);
    ctx.connect(parentId, "out_opt", optId);
    for (final childId in entryPoolIds) {
      ctx.connect(parentId, "out_entry_pool", childId);
    }
    for (final childId in exitPoolIds) {
      ctx.connect(parentId, "out_exit_pool", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final baseNetId = ctx.childId(nodeId, "out_base_net")!;
    final featIds = ctx.childIds(nodeId, "out_feat_pool");
    final actionsId = ctx.childId(nodeId, "out_actions")!;
    final penaltiesId = ctx.childId(nodeId, "out_penalties")!;
    final stopCondsId = ctx.childId(nodeId, "out_stop_conds")!;
    final optId = ctx.childId(nodeId, "out_opt")!;
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

    return {
      "base_net": NetworkGen.assemble(ctx, baseNetId),
      "feat_pool": featPoolList,
      "feat_selection": data.featSelection,
      "actions": ActionsGen.assemble(ctx, actionsId),
      "penalties": PenaltiesGen.assemble(ctx, penaltiesId),
      "stop_conds": StopConds.assemble(ctx, stopCondsId),
      "opt": GeneticOpt.assemble(ctx, optId),
      "entry_pool": entryPoolList,
      "entry_selection": data.entrySelection,
      "exit_pool": exitPoolList,
      "exit_selection": data.exitSelection
    };
  }
}

class Experiment extends NodeObject {
  double valSize;
  double testSize;
  int cvFolds;
  double foldSize;
  String backtestSchemaId;
  String strategyId;

  @override
  String get nodeType => "experiment";

  Experiment({
    required this.valSize,
    required this.testSize,
    required this.cvFolds,
    required this.foldSize,
    required this.backtestSchemaId,
    required this.strategyId
  });

  static List<Port> ports() {
    return outputPorts(["backtest_schema", "strategy"]);
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
    required this.title,
    required this.valSize,
    required this.testSize,
    required this.cvFolds,
    required this.foldSize,
    required this.backtestSchemaId,
    required this.strategyId
  });

  static List<Port> ports() {
    return outputPorts(["backtest_schema", "strategy"]);
  }
}

// Widget classes

List<int> parseIntList(String val) {
  return val.split(",")
      .map((str) => str.trim())
      .where((str) => str.isNotEmpty)
      .map((str) => int.tryParse(str) ?? 0)
      .toList();
}

class BacktestSchemaContent extends StatelessWidget {
  final BacktestSchema data;

  const BacktestSchemaContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "startOffset",
          value: data.startOffset.toString(),
          onChanged: (val) => data.startOffset = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "startBal",
          value: data.startBalance.toString(),
          onChanged: (val) => data.startBalance = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "delay",
          value: data.delay.toString(),
          onChanged: (val) => data.delay = int.tryParse(val) ?? 0
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
        NodeTextField(
          label: "posSize",
          value: data.positionSize.toString(),
          onChanged: (val) => data.positionSize = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxPos",
          value: data.maxPositions.toString(),
          onChanged: (val) => data.maxPositions = int.tryParse(val) ?? 0
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
        NodeTextField(
          label: "entries",
          value: data.entryIndices.join(","),
          onChanged: (val) {
            data.entryIndices = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "stopLoss",
          value: data.stopLoss.toString(),
          onChanged: (val) => data.stopLoss = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "takeProfit",
          value: data.takeProfit.toString(),
          onChanged: (val) => data.takeProfit = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxHold",
          value: data.maxHoldTime.toString(),
          onChanged: (val) => data.maxHoldTime = int.tryParse(val) ?? 0
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
    return NodeDropdown<String>(
      label: "type",
      value: data.type,
      options: ["logic_net", "decision_net"],
      labelFor: (val) => val,
      onChanged: (val) => data.type = val
    );
  }
}

class PenaltiesGenContent extends StatelessWidget {
  final PenaltiesGen data;

  const PenaltiesGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      value: data.type,
      options: ["logic_penalties", "decision_penalties"],
      labelFor: (val) => val,
      onChanged: (val) => data.type = val
    );
  }
}

class ActionsGenContent extends StatelessWidget {
  final ActionsGen data;

  const ActionsGenContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      value: data.type,
      options: ["logic_actions", "decision_actions"],
      labelFor: (val) => val,
      onChanged: (val) => data.type = val
    );
  }
}

class StrategyContent extends StatelessWidget {
  final Strategy data;

  const StrategyContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Text(
      "strategy",
      style: Theme.of(context).textTheme.bodyMedium
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
        NodeTextField(
          label: "featSel",
          value: data.featSelection.join(","),
          onChanged: (val) {
            data.featSelection = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "entrySel",
          value: data.entrySelection.join(","),
          onChanged: (val) {
            data.entrySelection = parseIntList(val);
          }
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "exitSel",
          value: data.exitSelection.join(","),
          onChanged: (val) {
            data.exitSelection = parseIntList(val);
          }
        )
      ]
    );
  }
}

class ExperimentContent extends StatelessWidget {
  final Experiment data;

  const ExperimentContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "valSize",
          value: data.valSize.toString(),
          onChanged: (val) => data.valSize = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "testSize",
          value: data.testSize.toString(),
          onChanged: (val) => data.testSize = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "cvFolds",
          value: data.cvFolds.toString(),
          onChanged: (val) => data.cvFolds = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "foldSize",
          value: data.foldSize.toString(),
          onChanged: (val) => data.foldSize = double.tryParse(val) ?? 0
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
        NodeTextField(
          label: "title",
          value: data.title,
          onChanged: (val) => data.title = val
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "valSize",
          value: data.valSize.toString(),
          onChanged: (val) => data.valSize = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "testSize",
          value: data.testSize.toString(),
          onChanged: (val) => data.testSize = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "cvFolds",
          value: data.cvFolds.toString(),
          onChanged: (val) => data.cvFolds = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "foldSize",
          value: data.foldSize.toString(),
          onChanged: (val) => data.foldSize = double.tryParse(val) ?? 0
        )
      ]
    );
  }
}
