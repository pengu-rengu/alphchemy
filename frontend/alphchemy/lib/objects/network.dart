import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

enum Anchor {
  fromStart, fromEnd;

  static Anchor fromJson(String json) {
    switch (json) {
      case "from_start": return Anchor.fromStart;
      case "from_end": return Anchor.fromEnd;
      default: throw ArgumentError("Invalid Anchor: $json");
    }
  }

  String toJson() {
    switch (this) {
      case Anchor.fromStart: return "from_start";
      case Anchor.fromEnd: return "from_end";
    }
  }
}

enum Gate {
  and, or, xor, nand, nor, xnor;

  static Gate fromJson(String json) {
    switch (json) {
      case "and": return Gate.and;
      case "or": return Gate.or;
      case "xor": return Gate.xor;
      case "nand": return Gate.nand;
      case "nor": return Gate.nor;
      case "xnor": return Gate.xnor;
      default: throw ArgumentError("Invalid Gate: $json");
    }
  }

  String toJson() {
    return name;
  }
}

class NodePtr extends NodeObject {
  Anchor anchor;
  int idx;

  @override
  String get nodeType => "node_ptr";

  NodePtr({this.anchor = Anchor.fromEnd, this.idx = 0});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final anchorStr = json["anchor"] as String;
    final anchor = Anchor.fromJson(anchorStr);
    final idx = json["idx"] as int;
    final data = NodePtr(anchor: anchor, idx: idx);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as NodePtr;
    return {
      "anchor": data.anchor.toJson(),
      "idx": data.idx
    };
  }
}

class InputNode extends NodeObject {
  double? threshold;
  int? featIdx;

  @override
  String get nodeType => "input_node";

  InputNode({this.threshold, this.featIdx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final threshold = nullDoubleFromJson(json["threshold"]);
    final featIdx = json["feat_idx"] as int?;
    final data = InputNode(threshold: threshold, featIdx: featIdx);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as InputNode;
    return {
      "type": "input",
      "threshold": data.threshold,
      "feat_idx": data.featIdx
    };
  }
}

class GateNode extends NodeObject {
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  String get nodeType => "gate_node";

  GateNode({this.gate, this.in1Idx, this.in2Idx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final gateStr = json["gate"] as String?;
    final gate = gateStr != null ? Gate.fromJson(gateStr) : null;
    final in1Idx = json["in1_idx"] as int?;
    final in2Idx = json["in2_idx"] as int?;
    final data = GateNode(gate: gate, in1Idx: in1Idx, in2Idx: in2Idx);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as GateNode;
    return {
      "type": "gate",
      "gate": data.gate?.toJson(),
      "in1_idx": data.in1Idx,
      "in2_idx": data.in2Idx
    };
  }
}

class BranchNode extends NodeObject {
  double? threshold;
  int? featIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "branch_node";

  BranchNode({
    this.threshold,
    this.featIdx,
    this.trueIdx,
    this.falseIdx
  });

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final threshold = nullDoubleFromJson(json["threshold"]);
    final featIdx = json["feat_idx"] as int?;
    final trueIdx = json["true_idx"] as int?;
    final falseIdx = json["false_idx"] as int?;
    final data = BranchNode(
      threshold: threshold,
      featIdx: featIdx,
      trueIdx: trueIdx,
      falseIdx: falseIdx
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as BranchNode;
    return {
      "type": "branch",
      "threshold": data.threshold,
      "feat_idx": data.featIdx,
      "true_idx": data.trueIdx,
      "false_idx": data.falseIdx
    };
  }
}

class RefNode extends NodeObject {
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "ref_node";

  RefNode({this.refIdx, this.trueIdx, this.falseIdx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refIdx = json["ref_idx"] as int?;
    final trueIdx = json["true_idx"] as int?;
    final falseIdx = json["false_idx"] as int?;
    final data = RefNode(refIdx: refIdx, trueIdx: trueIdx, falseIdx: falseIdx);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as RefNode;
    return {
      "type": "ref",
      "ref_idx": data.refIdx,
      "true_idx": data.trueIdx,
      "false_idx": data.falseIdx
    };
  }
}

class LogicNet extends NodeObject {
  List<String> nodeIds;
  bool defaultValue;

  @override
  String get nodeType => "logic_net";

  LogicNet({this.nodeIds = const [], this.defaultValue = false});

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["nodes"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final nodeIds = <String>[];
    final rawNodes = json["nodes"] as List<dynamic>?;
    if (rawNodes != null) {
      for (final raw in rawNodes) {
        final map = raw as Map<String, dynamic>;
        nodeIds.add(flattenLogicNode(ctx, map));
      }
    }
    final defaultValue = json["default_value"] as bool? ?? false;
    final data = LogicNet(nodeIds: nodeIds, defaultValue: defaultValue);
    final parentId = ctx.addNode(data);
    for (final childId in nodeIds) {
      ctx.connect(parentId, "out_nodes", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as LogicNet;
    final childNodeIds = ctx.childIds(nodeId, "out_nodes");
    final nodesList = childNodeIds.map((id) {
      return assembleLogicNode(ctx, id);
    }).toList();
    return {
      "nodes": nodesList,
      "default_value": data.defaultValue
    };
  }
}

class DecisionNet extends NodeObject {
  List<String> nodeIds;
  int maxTrailLen;
  bool defaultValue;

  @override
  String get nodeType => "decision_net";

  DecisionNet({
    this.nodeIds = const [],
    this.maxTrailLen = 10,
    this.defaultValue = false
  });

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["nodes"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final nodeIds = <String>[];
    final rawNodes = json["nodes"] as List<dynamic>?;
    if (rawNodes != null) {
      for (final raw in rawNodes) {
        final map = raw as Map<String, dynamic>;
        nodeIds.add(flattenDecisionNode(ctx, map));
      }
    }
    final maxTrailLen = json["max_trail_len"] as int? ?? 10;
    final defaultValue = json["default_value"] as bool? ?? false;
    final data = DecisionNet(
      nodeIds: nodeIds,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue
    );
    final parentId = ctx.addNode(data);
    for (final childId in nodeIds) {
      ctx.connect(parentId, "out_nodes", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as DecisionNet;
    final childNodeIds = ctx.childIds(nodeId, "out_nodes");
    final nodesList = childNodeIds.map((id) {
      return assembleDecisionNode(ctx, id);
    }).toList();
    return {
      "nodes": nodesList,
      "max_trail_len": data.maxTrailLen,
      "default_value": data.defaultValue
    };
  }
}

class LogicPenalties extends NodeObject {
  double node;
  double input;
  double gate;
  double recurrence;
  double feedforward;
  double usedFeat;
  double unusedFeat;

  @override
  String get nodeType => "logic_penalties";

  LogicPenalties({
    this.node = 0.0,
    this.input = 0.0,
    this.gate = 0.0,
    this.recurrence = 0.0,
    this.feedforward = 0.0,
    this.usedFeat = 0.0,
    this.unusedFeat = 0.0
  });

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final data = LogicPenalties(
      node: doubleFromJson(json["node"]),
      input: doubleFromJson(json["input"]),
      gate: doubleFromJson(json["gate"]),
      recurrence: doubleFromJson(json["recurrence"]),
      feedforward: doubleFromJson(json["feedforward"]),
      usedFeat: doubleFromJson(json["used_feat"]),
      unusedFeat: doubleFromJson(json["unused_feat"])
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as LogicPenalties;
    return {
      "node": data.node,
      "input": data.input,
      "gate": data.gate,
      "recurrence": data.recurrence,
      "feedforward": data.feedforward,
      "used_feat": data.usedFeat,
      "unused_feat": data.unusedFeat
    };
  }
}

class DecisionPenalties extends NodeObject {
  double node;
  double branch;
  double ref;
  double leaf;
  double nonLeaf;
  double usedFeat;
  double unusedFeat;

  @override
  String get nodeType => "decision_penalties";

  DecisionPenalties({
    this.node = 0.0,
    this.branch = 0.0,
    this.ref = 0.0,
    this.leaf = 0.0,
    this.nonLeaf = 0.0,
    this.usedFeat = 0.0,
    this.unusedFeat = 0.0
  });

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final data = DecisionPenalties(
      node: doubleFromJson(json["node"]),
      branch: doubleFromJson(json["branch"]),
      ref: doubleFromJson(json["ref"]),
      leaf: doubleFromJson(json["leaf"]),
      nonLeaf: doubleFromJson(json["non_leaf"]),
      usedFeat: doubleFromJson(json["used_feat"]),
      unusedFeat: doubleFromJson(json["unused_feat"])
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as DecisionPenalties;
    return {
      "node": data.node,
      "branch": data.branch,
      "ref": data.ref,
      "leaf": data.leaf,
      "non_leaf": data.nonLeaf,
      "used_feat": data.usedFeat,
      "unused_feat": data.unusedFeat
    };
  }
}

// Dispatchers

String flattenLogicNode(FlattenContext ctx, Map<String, dynamic> json) {
  final type = json["type"] as String;
  if (type == "input") {
    return InputNode.flatten(ctx, json);
  }
  return GateNode.flatten(ctx, json);
}

Map<String, dynamic> assembleLogicNode(AssembleContext ctx, String nodeId) {
  final node = ctx.findNode(nodeId)!;
  if (node.data is InputNode) {
    return InputNode.assemble(ctx, nodeId);
  }
  return GateNode.assemble(ctx, nodeId);
}

String flattenDecisionNode(FlattenContext ctx, Map<String, dynamic> json) {
  final type = json["type"] as String;
  if (type == "branch") {
    return BranchNode.flatten(ctx, json);
  }
  return RefNode.flatten(ctx, json);
}

Map<String, dynamic> assembleDecisionNode(AssembleContext ctx, String nodeId) {
  final node = ctx.findNode(nodeId)!;
  if (node.data is BranchNode) {
    return BranchNode.assemble(ctx, nodeId);
  }
  return RefNode.assemble(ctx, nodeId);
}

// Widget classes

class NodePtrContent extends StatelessWidget {
  final NodePtr data;

  const NodePtrContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeDropdown<Anchor>(
          label: "anchor",
          value: data.anchor,
          options: Anchor.values,
          labelFor: (val) => val.name,
          onChanged: (val) => data.anchor = val
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "idx",
          value: data.idx.toString(),
          onChanged: (val) => data.idx = int.tryParse(val) ?? 0
        )
      ]
    );
  }
}

class InputNodeContent extends StatelessWidget {
  final InputNode data;

  const InputNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return NodeTextField(
      label: "threshold",
      value: data.threshold?.toString() ?? "",
      onChanged: (val) => data.threshold = double.tryParse(val)
    );
  }
}

class GateNodeContent extends StatelessWidget {
  final GateNode data;

  const GateNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<Gate>(
      label: "gate",
      value: data.gate ?? Gate.and,
      options: Gate.values,
      labelFor: (val) => val.name,
      onChanged: (val) => data.gate = val
    );
  }
}

class BranchNodeContent extends StatelessWidget {
  final BranchNode data;

  const BranchNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return NodeTextField(
      label: "threshold",
      value: data.threshold?.toString() ?? "",
      onChanged: (val) => data.threshold = double.tryParse(val)
    );
  }
}

class RefNodeContent extends StatelessWidget {
  final RefNode data;

  const RefNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Text(
      "ref_node",
      style: Theme.of(context).textTheme.bodyMedium
    );
  }
}

class LogicNetContent extends StatelessWidget {
  final LogicNet data;

  const LogicNetContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return NodeCheckbox(
      label: "default",
      value: data.defaultValue,
      onChanged: (val) => data.defaultValue = val
    );
  }
}

class DecisionNetContent extends StatelessWidget {
  final DecisionNet data;

  const DecisionNetContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "maxTrail",
          value: data.maxTrailLen.toString(),
          onChanged: (val) => data.maxTrailLen = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeCheckbox(
          label: "default",
          value: data.defaultValue,
          onChanged: (val) => data.defaultValue = val
        )
      ]
    );
  }
}

class LogicPenaltiesContent extends StatelessWidget {
  final LogicPenalties data;

  const LogicPenaltiesContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "node",
          value: data.node.toString(),
          onChanged: (val) => data.node = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "input",
          value: data.input.toString(),
          onChanged: (val) => data.input = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "gate",
          value: data.gate.toString(),
          onChanged: (val) => data.gate = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "recurrence",
          value: data.recurrence.toString(),
          onChanged: (val) => data.recurrence = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "feedfwd",
          value: data.feedforward.toString(),
          onChanged: (val) => data.feedforward = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "usedFeat",
          value: data.usedFeat.toString(),
          onChanged: (val) => data.usedFeat = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "unusedFeat",
          value: data.unusedFeat.toString(),
          onChanged: (val) => data.unusedFeat = double.tryParse(val) ?? 0
        )
      ]
    );
  }
}

class DecisionPenaltiesContent extends StatelessWidget {
  final DecisionPenalties data;

  const DecisionPenaltiesContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "node",
          value: data.node.toString(),
          onChanged: (val) => data.node = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "branch",
          value: data.branch.toString(),
          onChanged: (val) => data.branch = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "ref",
          value: data.ref.toString(),
          onChanged: (val) => data.ref = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "leaf",
          value: data.leaf.toString(),
          onChanged: (val) => data.leaf = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "nonLeaf",
          value: data.nonLeaf.toString(),
          onChanged: (val) => data.nonLeaf = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "usedFeat",
          value: data.usedFeat.toString(),
          onChanged: (val) => data.usedFeat = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "unusedFeat",
          value: data.unusedFeat.toString(),
          onChanged: (val) => data.unusedFeat = double.tryParse(val) ?? 0
        )
      ]
    );
  }
}
