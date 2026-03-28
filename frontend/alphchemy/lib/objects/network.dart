import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
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
    final refs = <String, String>{};
    final anchorStr = stringOrDefault(json, "anchor", "anchor", "from_end", refs);
    final anchor = Anchor.fromJson(anchorStr);
    final idx = intOrDefault(json, "idx", "idx", 0, refs);
    final data = NodePtr(anchor: anchor, idx: idx);
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as NodePtr;
    return {
      "anchor": assembleField(data.anchor.toJson(), "anchor", data.paramRefs),
      "idx": assembleField(data.idx, "idx", data.paramRefs)
    };
  }
}

class InputNode extends NodeObject {
  int idx;
  double? threshold;
  int? featIdx;

  @override
  String get nodeType => "input_node";

  InputNode({this.idx = 0, this.threshold, this.featIdx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final refs = <String, String>{};
    final threshold = nullDoubleOrDefault(json, "threshold", "threshold", refs);
    final featIdx = nullIntOrDefault(json, "feat_idx", "featIdx", refs);
    final data = InputNode(idx: idx, threshold: threshold, featIdx: featIdx);
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as InputNode;
    return {
      "type": "input",
      "threshold": assembleField(data.threshold, "threshold", data.paramRefs),
      "feat_idx": assembleField(data.featIdx, "featIdx", data.paramRefs)
    };
  }
}

class GateNode extends NodeObject {
  int idx;
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  String get nodeType => "gate_node";

  GateNode({this.idx = 0, this.gate, this.in1Idx, this.in2Idx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final paramRefs = <String, String>{};
    final gateStr = json["gate"] as String?;
    final paramKey = paramKeyFromJson(json["gate"]);
    Gate? gate;
    if (paramKey != null) {
      paramRefs["gate"] = paramKey;
    } else if (gateStr != null) {
      gate = Gate.fromJson(gateStr);
    }
    final in1Idx = nullIntOrDefault(json, "in1_idx", "in1Idx", paramRefs);
    final in2Idx = nullIntOrDefault(json, "in2_idx", "in2Idx", paramRefs);
    final data = GateNode(idx: idx, gate: gate, in1Idx: in1Idx, in2Idx: in2Idx);
    data.paramRefs.addAll(paramRefs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as GateNode;
    return {
      "type": "gate",
      "gate": assembleField(data.gate?.toJson(), "gate", data.paramRefs),
      "in1_idx": assembleField(data.in1Idx, "in1Idx", data.paramRefs),
      "in2_idx": assembleField(data.in2Idx, "in2Idx", data.paramRefs)
    };
  }
}

class BranchNode extends NodeObject {
  int idx;
  double? threshold;
  int? featIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "branch_node";

  BranchNode({this.idx = 0, this.threshold, this.featIdx, this.trueIdx, this.falseIdx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final refs = <String, String>{};
    final threshold = nullDoubleOrDefault(json, "threshold", "threshold", refs);
    final featIdx = nullIntOrDefault(json, "feat_idx", "featIdx", refs);
    final trueIdx = nullIntOrDefault(json, "true_idx", "trueIdx", refs);
    final falseIdx = nullIntOrDefault(json, "false_idx", "falseIdx", refs);
    final data = BranchNode(
      idx: idx,
      threshold: threshold,
      featIdx: featIdx,
      trueIdx: trueIdx,
      falseIdx: falseIdx
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as BranchNode;
    return {
      "type": "branch",
      "threshold": assembleField(data.threshold, "threshold", data.paramRefs),
      "feat_idx": assembleField(data.featIdx, "featIdx", data.paramRefs),
      "true_idx": assembleField(data.trueIdx, "trueIdx", data.paramRefs),
      "false_idx": assembleField(data.falseIdx, "falseIdx", data.paramRefs)
    };
  }
}

class RefNode extends NodeObject {
  int idx;
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "ref_node";

  RefNode({this.idx = 0, this.refIdx, this.trueIdx, this.falseIdx});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final refs = <String, String>{};
    final refIdx = nullIntOrDefault(json, "ref_idx", "refIdx", refs);
    final trueIdx = nullIntOrDefault(json, "true_idx", "trueIdx", refs);
    final falseIdx = nullIntOrDefault(json, "false_idx", "falseIdx", refs);
    final data = RefNode(idx: idx, refIdx: refIdx, trueIdx: trueIdx, falseIdx: falseIdx);
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as RefNode;
    return {
      "type": "ref",
      "ref_idx": assembleField(data.refIdx, "refIdx", data.paramRefs),
      "true_idx": assembleField(data.trueIdx, "trueIdx", data.paramRefs),
      "false_idx": assembleField(data.falseIdx, "falseIdx", data.paramRefs)
    };
  }
}

class LogicNet extends NodeObject {
  List<String> nodeIds;
  List<int> nodeSelection;
  bool defaultValue;

  @override
  String get nodeType => "logic_net";

  LogicNet({this.nodeIds = const [], this.nodeSelection = const [], this.defaultValue = false});

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["nodes"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final nodeIds = <String>[];
    final rawNodes = json["node_pool"] as List<dynamic>?;
    if (rawNodes != null) {
      for (var i = 0; i < rawNodes.length; i++) {
        final map = rawNodes[i] as Map<String, dynamic>;
        final nodeId = LogicNet.flattenNode(ctx, map, i);
        nodeIds.add(nodeId);
      }
    }
    final refs = <String, String>{};
    final nodeSelection = intListOrDefault(json, "node_selection", "nodeSelection", const [], refs);
    final defaultValue = boolOrDefault(json, "default_value", "defaultValue", false, refs);
    final data = LogicNet(
      nodeIds: nodeIds,
      nodeSelection: nodeSelection,
      defaultValue: defaultValue
    );
    data.paramRefs.addAll(refs);
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
    childNodeIds.sort((idA, idB) {
      final idxA = LogicNet.nodeIdx(ctx.findNode(idA)!.data);
      final idxB = LogicNet.nodeIdx(ctx.findNode(idB)!.data);
      return idxA.compareTo(idxB);
    });
    final nodesList = childNodeIds.map((id) {
      return LogicNet.assembleNode(ctx, id);
    }).toList();
    return {
      "node_pool": nodesList,
      "node_selection": assembleField(data.nodeSelection, "nodeSelection", data.paramRefs),
      "default_value": assembleField(data.defaultValue, "defaultValue", data.paramRefs)
    };
  }

  static int nodeIdx(NodeObject data) {
    if (data is InputNode) return data.idx;
    return (data as GateNode).idx;
  }

  static String flattenNode(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final type = json["type"] as String;
    if (type == "input") {
      return InputNode.flatten(ctx, json, idx);
    }
    return GateNode.flatten(ctx, json, idx);
  }

  static Map<String, dynamic> assembleNode(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    if (node.data is InputNode) {
      return InputNode.assemble(ctx, nodeId);
    }
    return GateNode.assemble(ctx, nodeId);
  }
}

class DecisionNet extends NodeObject {
  List<String> nodeIds;
  List<int> nodeSelection;
  int maxTrailLen;
  bool defaultValue;

  @override
  String get nodeType => "decision_net";

  DecisionNet({
    this.nodeIds = const [],
    this.nodeSelection = const [],
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
    final rawNodes = json["node_pool"] as List<dynamic>?;
    if (rawNodes != null) {
      for (var i = 0; i < rawNodes.length; i++) {
        final map = rawNodes[i] as Map<String, dynamic>;
        final nodeId = DecisionNet.flattenNode(ctx, map, i);
        nodeIds.add(nodeId);
      }
    }

    final paramRefs = <String, String>{};
    final nodeSelection = intListOrDefault(json, "node_selection", "nodeSelection", const [], paramRefs);
    final maxTrailLen = intOrDefault(json, "max_trail_len", "maxTrailLen", 10, paramRefs);
    final defaultValue = boolOrDefault(json, "default_value", "defaultValue", false, paramRefs);
    final data = DecisionNet(
      nodeIds: nodeIds,
      nodeSelection: nodeSelection,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue
    );
    data.paramRefs.addAll(paramRefs);
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
    childNodeIds.sort((idA, idB) {
      final idxA = DecisionNet.nodeIdx(ctx.findNode(idA)!.data);
      final idxB = DecisionNet.nodeIdx(ctx.findNode(idB)!.data);
      return idxA.compareTo(idxB);
    });
    final nodesList = childNodeIds.map((id) {
      return DecisionNet.assembleNode(ctx, id);
    }).toList();
    return {
      "node_pool": nodesList,
      "node_selection": assembleField(data.nodeSelection, "nodeSelection", data.paramRefs),
      "max_trail_len": assembleField(data.maxTrailLen, "maxTrailLen", data.paramRefs),
      "default_value": assembleField(data.defaultValue, "defaultValue", data.paramRefs)
    };
  }

  static int nodeIdx(NodeObject data) {
    if (data is BranchNode) return data.idx;
    return (data as RefNode).idx;
  }

  static String flattenNode(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final type = json["type"] as String;
    if (type == "branch") {
      return BranchNode.flatten(ctx, json, idx);
    }
    return RefNode.flatten(ctx, json, idx);
  }

  static Map<String, dynamic> assembleNode(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    if (node.data is BranchNode) {
      return BranchNode.assemble(ctx, nodeId);
    }
    return RefNode.assemble(ctx, nodeId);
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
    final refs = <String, String>{};
    final data = LogicPenalties(
      node: doubleOrDefault(json, "node", "node", 0.0, refs),
      input: doubleOrDefault(json, "input", "input", 0.0, refs),
      gate: doubleOrDefault(json, "gate", "gate", 0.0, refs),
      recurrence: doubleOrDefault(json, "recurrence", "recurrence", 0.0, refs),
      feedforward: doubleOrDefault(json, "feedforward", "feedforward", 0.0, refs),
      usedFeat: doubleOrDefault(json, "used_feat", "usedFeat", 0.0, refs),
      unusedFeat: doubleOrDefault(json, "unused_feat", "unusedFeat", 0.0, refs)
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as LogicPenalties;
    return {
      "node": assembleField(data.node, "node", data.paramRefs),
      "input": assembleField(data.input, "input", data.paramRefs),
      "gate": assembleField(data.gate, "gate", data.paramRefs),
      "recurrence": assembleField(data.recurrence, "recurrence", data.paramRefs),
      "feedforward": assembleField(data.feedforward, "feedforward", data.paramRefs),
      "used_feat": assembleField(data.usedFeat, "usedFeat", data.paramRefs),
      "unused_feat": assembleField(data.unusedFeat, "unusedFeat", data.paramRefs)
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
    final refs = <String, String>{};
    final data = DecisionPenalties(
      node: doubleOrDefault(json, "node", "node", 0.0, refs),
      branch: doubleOrDefault(json, "branch", "branch", 0.0, refs),
      ref: doubleOrDefault(json, "ref", "ref", 0.0, refs),
      leaf: doubleOrDefault(json, "leaf", "leaf", 0.0, refs),
      nonLeaf: doubleOrDefault(json, "non_leaf", "nonLeaf", 0.0, refs),
      usedFeat: doubleOrDefault(json, "used_feat", "usedFeat", 0.0, refs),
      unusedFeat: doubleOrDefault(json, "unused_feat", "unusedFeat", 0.0, refs)
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as DecisionPenalties;
    return {
      "node": assembleField(data.node, "node", data.paramRefs),
      "branch": assembleField(data.branch, "branch", data.paramRefs),
      "ref": assembleField(data.ref, "ref", data.paramRefs),
      "leaf": assembleField(data.leaf, "leaf", data.paramRefs),
      "non_leaf": assembleField(data.nonLeaf, "nonLeaf", data.paramRefs),
      "used_feat": assembleField(data.usedFeat, "usedFeat", data.paramRefs),
      "unused_feat": assembleField(data.unusedFeat, "unusedFeat", data.paramRefs)
    };
  }
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
        ParamField(
          fieldKey: "anchor",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeDropdown<Anchor>(
            label: "anchor",
            value: data.anchor,
            options: Anchor.values,
            labelFor: (val) => val.name,
            onChanged: (val) => data.anchor = val
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "idx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "idx",
            value: data.idx.toString(),
            onChanged: (val) => data.idx = int.tryParse(val) ?? 0
          )
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "idx",
          value: data.idx.toString(),
          onChanged: (val) => data.idx = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "threshold",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "threshold",
            value: data.threshold?.toString() ?? "",
            onChanged: (val) => data.threshold = double.tryParse(val)
          )
        )
      ]
    );
  }
}

class GateNodeContent extends StatelessWidget {
  final GateNode data;

  const GateNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "idx",
          value: data.idx.toString(),
          onChanged: (val) => data.idx = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "gate",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeDropdown<Gate>(
            label: "gate",
            value: data.gate ?? Gate.and,
            options: Gate.values,
            labelFor: (val) => val.name,
            onChanged: (val) => data.gate = val
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "in1Idx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "in1Idx",
            value: data.in1Idx?.toString() ?? "",
            onChanged: (val) => data.in1Idx = int.tryParse(val)
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "in2Idx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "in2Idx",
            value: data.in2Idx?.toString() ?? "",
            onChanged: (val) => data.in2Idx = int.tryParse(val)
          )
        )
      ]
    );
  }
}

class BranchNodeContent extends StatelessWidget {
  final BranchNode data;

  const BranchNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "idx",
          value: data.idx.toString(),
          onChanged: (val) => data.idx = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "threshold",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "threshold",
            value: data.threshold?.toString() ?? "",
            onChanged: (val) => data.threshold = double.tryParse(val)
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "trueIdx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "trueIdx",
            value: data.trueIdx?.toString() ?? "",
            onChanged: (val) => data.trueIdx = int.tryParse(val)
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "falseIdx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "falseIdx",
            value: data.falseIdx?.toString() ?? "",
            onChanged: (val) => data.falseIdx = int.tryParse(val)
          )
        )
      ]
    );
  }
}

class RefNodeContent extends StatelessWidget {
  final RefNode data;

  const RefNodeContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "idx",
          value: data.idx.toString(),
          onChanged: (val) => data.idx = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "refIdx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "refIdx",
            value: data.refIdx?.toString() ?? "",
            onChanged: (val) => data.refIdx = int.tryParse(val)
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "trueIdx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "trueIdx",
            value: data.trueIdx?.toString() ?? "",
            onChanged: (val) => data.trueIdx = int.tryParse(val)
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "falseIdx",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "falseIdx",
            value: data.falseIdx?.toString() ?? "",
            onChanged: (val) => data.falseIdx = int.tryParse(val)
          )
        )
      ]
    );
  }
}

class LogicNetContent extends StatelessWidget {
  final LogicNet data;

  const LogicNetContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "nodeSelection",
          paramType: ParamType.intListType,
          nodeData: data,
          child: NodeListField<int>(
            label: "nodeSel",
            items: data.nodeSelection,
            display: (val) => val.toString(),
            parse: (str) => int.tryParse(str) ?? 0,
            defaultItem: () => 0,
            onChanged: (list) { data.nodeSelection = list; }
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "defaultValue",
          paramType: ParamType.boolType,
          nodeData: data,
          child: NodeCheckbox(
            label: "default",
            value: data.defaultValue,
            onChanged: (val) => data.defaultValue = val
          )
        )
      ]
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
        ParamField(
          fieldKey: "nodeSelection",
          paramType: ParamType.intListType,
          nodeData: data,
          child: NodeListField<int>(
            label: "nodeSel",
            items: data.nodeSelection,
            display: (val) => val.toString(),
            parse: (str) => int.tryParse(str) ?? 0,
            defaultItem: () => 0,
            onChanged: (list) { data.nodeSelection = list; }
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "maxTrailLen",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "maxTrail",
            value: data.maxTrailLen.toString(),
            onChanged: (val) => data.maxTrailLen = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "defaultValue",
          paramType: ParamType.boolType,
          nodeData: data,
          child: NodeCheckbox(
            label: "default",
            value: data.defaultValue,
            onChanged: (val) => data.defaultValue = val
          )
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
        ParamField(fieldKey: "node", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "node", value: data.node.toString(), onChanged: (val) => data.node = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "input", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "input", value: data.input.toString(), onChanged: (val) => data.input = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "gate", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "gate", value: data.gate.toString(), onChanged: (val) => data.gate = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "recurrence", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "recurrence", value: data.recurrence.toString(), onChanged: (val) => data.recurrence = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "feedforward", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "feedfwd", value: data.feedforward.toString(), onChanged: (val) => data.feedforward = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "usedFeat", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "usedFeat", value: data.usedFeat.toString(), onChanged: (val) => data.usedFeat = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "unusedFeat", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "unusedFeat", value: data.unusedFeat.toString(), onChanged: (val) => data.unusedFeat = double.tryParse(val) ?? 0
        ))
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
        ParamField(fieldKey: "node", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "node", value: data.node.toString(), onChanged: (val) => data.node = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "branch", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "branch", value: data.branch.toString(), onChanged: (val) => data.branch = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "ref", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "ref", value: data.ref.toString(), onChanged: (val) => data.ref = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "leaf", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "leaf", value: data.leaf.toString(), onChanged: (val) => data.leaf = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "nonLeaf", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "nonLeaf", value: data.nonLeaf.toString(), onChanged: (val) => data.nonLeaf = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "usedFeat", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "usedFeat", value: data.usedFeat.toString(), onChanged: (val) => data.usedFeat = double.tryParse(val) ?? 0
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "unusedFeat", paramType: ParamType.floatType, nodeData: data, child: NodeTextField(
          label: "unusedFeat", value: data.unusedFeat.toString(), onChanged: (val) => data.unusedFeat = double.tryParse(val) ?? 0
        ))
      ]
    );
  }
}
