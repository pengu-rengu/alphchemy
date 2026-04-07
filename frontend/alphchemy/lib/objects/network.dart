import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

enum Anchor {
  fromStart, fromEnd;

  static Anchor fromJson(dynamic value) {
    switch (castStr(value)) {
      case "from_start": return Anchor.fromStart;
      case "from_end": return Anchor.fromEnd;
      default: throw ArgumentError("Invalid Anchor: $value");
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

  static Gate fromJson(dynamic value) {
    switch (castStr(value)) {
      case "and": return Gate.and;
      case "or": return Gate.or;
      case "xor": return Gate.xor;
      case "nand": return Gate.nand;
      case "nor": return Gate.nor;
      case "xnor": return Gate.xnor;
      default: throw ArgumentError("Invalid gate: $value");
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
  NodeType get nodeType => NodeType.nodePtr;

  NodePtr({this.anchor = Anchor.fromStart, this.idx = 0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "idx": idx = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "anchor": anchor = value as Anchor;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "anchor" => anchor.name,
      "idx" => idx.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final anchor = getField<Anchor>(json, "anchor", Anchor.fromStart, paramRefs, Anchor.fromJson);
    final idx = getField<int>(json, "idx", 0, paramRefs);
    
    final data = NodePtr(anchor: anchor, idx: idx, paramRefs: paramRefs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as NodePtr;

    final anchor = assembleField(data.anchor.toJson(), "anchor", data);
    final idx = assembleField(data.idx, "idx", data);

    return {
      "anchor": anchor,
      "idx": idx
    };
  }
}

class InputNode extends NodeObject {
  String id;
  double? threshold;
  String? featId;

  @override
  NodeType get nodeType => NodeType.inputNode;

  InputNode({this.id = "", this.threshold, this.featId, super.paramRefs});

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id": id = text;
      case "threshold": threshold = double.tryParse(text);
      case "feat_id": featId = text.isEmpty ? null : text;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "threshold" => threshold?.toString() ?? "",
      "feat_id" => featId ?? "",
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final id = getField<String>(json, "id", "", paramRefs);
    final threshold = getField<double?>(json, "threshold", null, paramRefs, doubleFromJson);
    final featId = getField<String?>(json, "feat_id", null, paramRefs);

    final data = InputNode(
      id: id,
      threshold: threshold,
      featId: featId,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as InputNode;

    final id = assembleField(data.id, "id", data);
    final threshold = assembleField(data.threshold, "threshold", data);
    final featId = assembleField(data.featId, "feat_id", data);

    return {
      "id": id,
      "type": "input",
      "threshold": threshold,
      "feat_id": featId
    };
  }
}

class GateNode extends NodeObject {
  String nodeId;
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  NodeType get nodeType => NodeType.gateNode;

  GateNode({this.nodeId = "", this.gate, this.in1Idx, this.in2Idx, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": nodeId = text;
      case "in1_idx": in1Idx = int.tryParse(text);
      case "in2_idx": in2Idx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "gate": gate = value as Gate;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => nodeId,
      "gate" => gate?.name ?? "",
      "in1_idx" => in1Idx?.toString() ?? "",
      "in2_idx" => in2Idx?.toString() ?? "",
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final nodeId = getField<String>(json, "id", "", paramRefs);
    final gate = getField<Gate?>(json, "gate", null, paramRefs, Gate.fromJson);
    final in1Idx = getField<int?>(json, "in1_idx", null, paramRefs);
    final in2Idx = getField<int?>(json, "in2_idx", null, paramRefs);

    final data = GateNode(
      nodeId: nodeId,
      gate: gate,
      in1Idx: in1Idx,
      in2Idx: in2Idx,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as GateNode;
    final id = assembleField(data.nodeId, "id", data);
    final gate = assembleField(data.gate?.toJson(), "gate", data);
    final in1Idx = assembleField(data.in1Idx, "in1_idx", data);
    final in2Idx = assembleField(data.in2Idx, "in2_idx", data);

    return {
      "id": id,
      "type": "gate",
      "gate": gate,
      "in1_idx": in1Idx,
      "in2_idx": in2Idx
    };
  }
}

class BranchNode extends NodeObject {
  String nodeId;
  double? threshold;
  String? featId;
  int? trueIdx;
  int? falseIdx;

  @override
  NodeType get nodeType => NodeType.branchNode;

  BranchNode({this.nodeId = "", this.threshold, this.featId, this.trueIdx, this.falseIdx, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": nodeId = text;
      case "threshold": threshold = double.tryParse(text);
      case "feat_id": featId = text.isEmpty ? null : text;
      case "true_idx": trueIdx = int.tryParse(text);
      case "false_idx": falseIdx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => nodeId,
      "threshold" => threshold?.toString() ?? "",
      "feat_id" => featId ?? "",
      "true_idx" => trueIdx?.toString() ?? "",
      "false_idx" => falseIdx?.toString() ?? "",
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final nodeId = getField<String>(json, "id", "", paramRefs);
    final threshold = getField<double?>(json, "threshold", null, paramRefs, doubleFromJson);
    final featId = getField<String?>(json, "feat_id", null, paramRefs);
    final trueIdx = getField<int?>(json, "true_idx", null, paramRefs);
    final falseIdx = getField<int?>(json, "false_idx", null, paramRefs);

    final data = BranchNode(
      nodeId: nodeId,
      threshold: threshold,
      featId: featId,
      trueIdx: trueIdx,
      falseIdx: falseIdx,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as BranchNode;

    final id = assembleField(data.nodeId, "id", data);
    final threshold = assembleField(data.threshold, "threshold", data);
    final featId = assembleField(data.featId, "feat_id", data);
    final trueIdx = assembleField(data.trueIdx, "true_idx", data);
    final falseIdx = assembleField(data.falseIdx, "false_idx", data);

    return {
      "id": id,
      "type": "branch",
      "threshold": threshold,
      "feat_id": featId,
      "true_idx": trueIdx,
      "false_idx": falseIdx
    };
  }
}

class RefNode extends NodeObject {
  String nodeId;
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  NodeType get nodeType => NodeType.refNode;

  RefNode({this.nodeId = "", this.refIdx, this.trueIdx, this.falseIdx, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": nodeId = text;
      case "ref_idx": refIdx = int.tryParse(text);
      case "true_idx": trueIdx = int.tryParse(text);
      case "false_idx": falseIdx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => nodeId,
      "ref_idx" => refIdx?.toString() ?? "",
      "true_idx" => trueIdx?.toString() ?? "",
      "false_idx" => falseIdx?.toString() ?? "",
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final nodeId = getField<String>(json, "id", "", paramRefs);
    final refIdx = getField<int?>(json, "ref_idx", null, paramRefs);
    final trueIdx = getField<int?>(json, "true_idx", null, paramRefs);
    final falseIdx = getField<int?>(json, "false_idx", null, paramRefs);

    final data = RefNode(
      nodeId: nodeId,
      refIdx: refIdx,
      trueIdx: trueIdx,
      falseIdx: falseIdx,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as RefNode;
    final id =  assembleField(data.nodeId, "id", data);
    final refIdx = assembleField(data.refIdx, "ref_idx", data);
    final trueIdx = assembleField(data.trueIdx, "true_idx", data);
    final falseIdx = assembleField(data.falseIdx, "false_idx", data);

    return {
      "id": id,
      "type": "ref",
      "ref_idx": refIdx,
      "true_idx": trueIdx,
      "false_idx": falseIdx
    };
  }
}

class LogicNet extends NodeObject {
  List<String> nodeSelection;
  bool defaultValue;

  @override
  NodeType get nodeType => NodeType.logicNet;

  LogicNet({this.nodeSelection = const [], this.defaultValue = false, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "node_selection": nodeSelection = parseList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "default_value": defaultValue = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    final nodeSelectionFormatted = nodeSelection.join(", ");

    return switch (fieldKey) {
      "node_selection" => nodeSelectionFormatted,
      "default_value" => defaultValue.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["nodes"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final nodeSelection = getField<List<String>>(json, "node_selection", const [], paramRefs, listFromJson<String>);
    final defaultValue = getField<bool>(json, "default_value", false, paramRefs);

    final data = LogicNet(
      nodeSelection: nodeSelection,
      defaultValue: defaultValue,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    for (final nodeJson in json["node_pool"] as List<dynamic>? ?? []) {
      final childId = LogicNet.flattenNode(ctx, nodeJson as Map<String, dynamic>);
      ctx.connect(parentId, "nodes", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as LogicNet;

    final childNodeIds = ctx.childIds(nodeId, "nodes");
    Map<String, dynamic> assembleNode(id) => LogicNet.assembleNode(ctx, id);
    final nodePool = childNodeIds.map(assembleNode).toList();

    final nodeSelection = assembleField(data.nodeSelection, "node_selection", data);
    final defaultValue = assembleField(data.defaultValue, "default_value", data);

    return {
      "node_pool": nodePool,
      "node_selection": nodeSelection,
      "default_value": defaultValue
    };
  }

  static String flattenNode(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"];
    return switch (type) {
      "input" => InputNode.flatten(ctx, json),
      "gate" => GateNode.flatten(ctx, json),
      _ => throw Exception("Unknown node type: $type")
    };
  }

  static Map<String, dynamic> assembleNode(AssembleContext ctx, String nodeId) {
    final nodeType = ctx.findNode(nodeId).data.nodeType;
    return switch (nodeType) {
      NodeType.inputNode => InputNode.assemble(ctx, nodeId),
      NodeType.gateNode => GateNode.assemble(ctx, nodeId),
      _ => throw Exception("Invalid node type for logic network: $nodeType")
    };
  }
}

class DecisionNet extends NodeObject {
  List<String> nodeSelection;
  int maxTrailLen;
  bool defaultValue;

  @override
  NodeType get nodeType => NodeType.decisionNet;

  DecisionNet({this.nodeSelection = const [], this.maxTrailLen = 1, this.defaultValue = false, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "node_selection": nodeSelection = parseList(text);
      case "max_trail_len": maxTrailLen = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "default_value": defaultValue = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "node_selection" => nodeSelection.join(", "),
      "max_trail_len" => maxTrailLen.toString(),
      "default_value" => defaultValue.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return [
      ...inputPort(),
      ...outputPorts(["nodes"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final nodeSelection = getField<List<String>>(json, "node_selection", const [], paramRefs, listFromJson<String>);
    final maxTrailLen = getField<int>(json, "max_trail_len", 10, paramRefs);
    final defaultValue = getField<bool>(json, "default_value", false, paramRefs);

    final data = DecisionNet(
      nodeSelection: nodeSelection,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue,
      paramRefs: paramRefs
    );
    final parentId = ctx.addNode(data);

    for (final nodeJson in json["node_pool"] as List<dynamic>? ?? []) {
      final childId = DecisionNet.flattenNode(ctx, nodeJson as Map<String, dynamic>);
      ctx.connect(parentId, "nodes", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as DecisionNet;

    final childNodeIds = ctx.childIds(nodeId, "nodes");
    Map<String, dynamic> assembleNode(id) => DecisionNet.assembleNode(ctx, id);
    final nodePool = childNodeIds.map(assembleNode).toList();

    final nodeSelection = assembleField(data.nodeSelection, "node_selection", data);
    final maxTrailLen = assembleField(data.maxTrailLen, "max_trail_len", data);
    final defaultValue = assembleField(data.defaultValue, "default_value", data);

    return {
      "node_pool": nodePool,
      "node_selection": nodeSelection,
      "max_trail_len": maxTrailLen,
      "default_value": defaultValue
    };
  }

  static String flattenNode(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"];
    return switch (type) {
      "branch" => BranchNode.flatten(ctx, json),
      "ref" => RefNode.flatten(ctx, json),
      _ => throw Exception("Unknown node type: $type")
    };
  }

  static Map<String, dynamic> assembleNode(AssembleContext ctx, String nodeId) {
    final nodeType = ctx.findNode(nodeId).data.nodeType;
    return switch (nodeType) {
      NodeType.branchNode => BranchNode.assemble(ctx, nodeId),
      NodeType.refNode => RefNode.assemble(ctx, nodeId),
      _ => throw Exception("Invalid node type for decision network: $nodeType")
    };
  }
}

class Network extends NodeObject {
  String type;

  @override
  NodeType get nodeType => NodeType.networkGen;

  Network({this.type = "logic", super.paramRefs});

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
      ...outputPorts(["logic_net", "decision_net"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final type = getField<String>(json, "type", "logic", paramRefs);

    final data = Network(type: type, paramRefs: paramRefs);
    final parentId = ctx.addNode(data);

    final logicNetJson = json["logic_net"] as Map<String, dynamic>?;
    if (logicNetJson != null) {
      final logicNetId = LogicNet.flatten(ctx, logicNetJson);
      ctx.connect(parentId, "logic_net", logicNetId);
    }

    final decisionNetJson = json["decision_net"] as Map<String, dynamic>?;
    if (decisionNetJson != null) {
      final decisionNetId = DecisionNet.flatten(ctx, decisionNetJson);
      ctx.connect(parentId, "decision_net", decisionNetId);
    }

    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as Network;

    final type =  assembleField(data.type, "type", data);

    final logicNetNodeId = ctx.childId(nodeId, "logic_net");
    final logicNet = logicNetNodeId != null ? LogicNet.assemble(ctx, logicNetNodeId) : null;

    final decisionNetNodeId = ctx.childId(nodeId, "decision_net");
    final decisionNet = decisionNetNodeId != null ? DecisionNet.assemble(ctx, decisionNetNodeId) : null;

    return {
      "type": type,
      "logic_net": logicNet,
      "decision_net": decisionNet
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
  NodeType get nodeType => NodeType.logicPenalties;

  LogicPenalties({this.node = 0.0, this.input = 0.0, this.gate = 0.0, this.recurrence = 0.0, this.feedforward = 0.0, this.usedFeat = 0.0, this.unusedFeat = 0.0, super.paramRefs});

  @override
  void updateField(String field, String text) {
    final value = double.tryParse(text) ?? 0.0;

    switch (field) {
      case "node": node = value;
      case "input": input = value;
      case "gate": gate = value;
      case "recurrence": recurrence = value;
      case "feedforward": feedforward = value;
      case "used_feat": usedFeat = value;
      case "unused_feat": unusedFeat = value;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "node" => node.toString(),
      "input" => input.toString(),
      "gate" => gate.toString(),
      "recurrence" => recurrence.toString(),
      "feedforward" => feedforward.toString(),
      "used_feat" => usedFeat.toString(),
      "unused_feat" => unusedFeat.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final node = getField<double>(json, "node", 0.0, paramRefs, doubleFromJson);
    final input = getField<double>(json, "input", 0.0, paramRefs, doubleFromJson);
    final gate = getField<double>(json, "gate", 0.0, paramRefs, doubleFromJson);
    final recurrence = getField<double>(json, "recurrence", 0.0, paramRefs, doubleFromJson);
    final feedforward = getField<double>(json, "feedforward", 0.0, paramRefs, doubleFromJson);
    final usedFeat = getField<double>(json, "used_feat", 0.0, paramRefs, doubleFromJson);
    final unusedFeat = getField<double>(json, "unused_feat", 0.0, paramRefs, doubleFromJson);

    final data = LogicPenalties(
      node: node,
      input: input,
      gate: gate,
      recurrence: recurrence,
      feedforward: feedforward,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as LogicPenalties;

    final node = assembleField(data.node, "node", data);
    final input = assembleField(data.input, "input", data);
    final gate = assembleField(data.gate, "gate", data);
    final recurrence = assembleField(data.recurrence, "recurrence", data);
    final feedforward = assembleField(data.feedforward, "feedforward", data);
    final usedFeat = assembleField(data.usedFeat, "used_feat", data);
    final unusedFeat = assembleField(data.unusedFeat, "unused_feat", data);

    return {
      "node": node,
      "input": input,
      "gate": gate,
      "recurrence": recurrence,
      "feedforward": feedforward,
      "used_feat": usedFeat,
      "unused_feat": unusedFeat
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
  NodeType get nodeType => NodeType.decisionPenalties;

  DecisionPenalties({this.node = 0.0, this.branch = 0.0, this.ref = 0.0, this.leaf = 0.0, this.nonLeaf = 0.0, this.usedFeat = 0.0, this.unusedFeat = 0.0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    final val = double.tryParse(text) ?? 0.0;
    switch (fieldKey) {
      case "node": node = val;
      case "branch": branch = val;
      case "ref": ref = val;
      case "leaf": leaf = val;
      case "non_leaf": nonLeaf = val;
      case "used_feat": usedFeat = val;
      case "unused_feat": unusedFeat = val;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "node" => node.toString(),
      "branch" => branch.toString(),
      "ref" => ref.toString(),
      "leaf" => leaf.toString(),
      "non_leaf" => nonLeaf.toString(),
      "used_feat" => usedFeat.toString(),
      "unused_feat" => unusedFeat.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};

    final node = getField<double>(json, "node", 0.0, refs, doubleFromJson);
    final branch = getField<double>(json, "branch", 0.0, refs, doubleFromJson);
    final ref = getField<double>(json, "ref", 0.0, refs, doubleFromJson);
    final leaf = getField<double>(json, "leaf", 0.0, refs, doubleFromJson);
    final nonLeaf = getField<double>(json, "non_leaf", 0.0, refs, doubleFromJson);
    final usedFeat = getField<double>(json, "used_feat", 0.0, refs, doubleFromJson);
    final unusedFeat = getField<double>(json, "unused_feat", 0.0, refs, doubleFromJson);

    final data = DecisionPenalties(
      node: node,
      branch: branch,
      ref: ref,
      leaf: leaf,
      nonLeaf: nonLeaf,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat,
      paramRefs: refs
    );

    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as DecisionPenalties;

    final node = assembleField(data.node, "node", data);
    final branch = assembleField(data.branch, "branch", data);
    final ref = assembleField(data.ref, "ref", data);
    final leaf = assembleField(data.leaf, "leaf", data);
    final nonLeaf = assembleField(data.nonLeaf, "non_leaf", data);
    final usedFeat = assembleField(data.usedFeat, "used_feat", data);
    final unusedFeat = assembleField(data.unusedFeat, "unused_feat", data);

    return {
      "node": node,
      "branch": branch,
      "ref": ref,
      "leaf": leaf,
      "non_leaf": nonLeaf,
      "used_feat": usedFeat,
      "unused_feat": unusedFeat
    };
  }
}

class Penalties extends NodeObject {
  String type;

  @override
  NodeType get nodeType => NodeType.penaltiesGen;

  Penalties({this.type = "logic", super.paramRefs});

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
      ...outputPorts(["logic_penalties", "decision_penalties"])
    ];
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final type = getField<String>(json, "type", "logic", paramRefs);

    final data = Penalties(type: type, paramRefs: paramRefs);
    final parentId = ctx.addNode(data);

    final logicPenaltiesJson = json["logic_penalties"] as Map<String, dynamic>?;
    if (logicPenaltiesJson != null) {
      final logicPenaltiesId = LogicPenalties.flatten(ctx, logicPenaltiesJson);
      ctx.connect(parentId, "logic_penalties", logicPenaltiesId);
    }

    final decisionPenaltiesJson = json["decision_penalties"] as Map<String, dynamic>?;
    if (decisionPenaltiesJson != null) {
      final decisionPenaltiesId = DecisionPenalties.flatten(ctx, decisionPenaltiesJson);
      ctx.connect(parentId, "decision_penalties", decisionPenaltiesId);
    }

    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as Penalties;

    final type = assembleField(data.type, "type", data);

    final logicId = ctx.childId(nodeId, "logic_penalties");
    final logicPenalties = logicId != null ? LogicPenalties.assemble(ctx, logicId) : null;

    final decisionId = ctx.childId(nodeId, "decision_penalties");
    final decisionPenalties = decisionId != null ? DecisionPenalties.assemble(ctx, decisionId) : null;

    return {
      "type": type,
      "logic_penalties": logicPenalties,
      "decision_penalties": decisionPenalties
    };
  }
}
