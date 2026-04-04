import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";
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

  static Gate? tryParse(String value) {
    try {
      return Gate.fromJson(value);
    } on ArgumentError {
      return null;
    }
  }

  static List<Gate> parseList(String text) {
    final parts = text.split(",");
    final result = <Gate>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final parsed = Gate.tryParse(trimmed);
      if (parsed == null) continue;
      result.add(parsed);
    }
    return result;
  }
}

class NodePtr extends NodeObject {
  Anchor anchor;
  int idx;

  @override
  String get nodeType => "node_ptr";

  NodePtr({this.anchor = Anchor.fromEnd, this.idx = 0});

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
  String nodeId;
  int idx;
  double? threshold;
  String? featId;

  @override
  String get nodeType => "input_node";

  InputNode({
    this.nodeId = "",
    this.idx = 0,
    this.threshold,
    this.featId
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
      case "idx": idx = int.tryParse(text) ?? 0;
      case "threshold": threshold = double.tryParse(text);
      case "featId": featId = text.isEmpty ? null : text;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "nodeId" => nodeId,
      "idx" => idx.toString(),
      "threshold" => NodeObject.formatNullable(threshold),
      "featId" => NodeObject.formatNullable(featId),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final refs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", refs);
    final threshold = nullDoubleOrDefault(json, "threshold", "threshold", refs);
    final featId = nullStringOrDefault(json, "feat_id", "featId", refs);
    final data = InputNode(
      nodeId: nodeId,
      idx: idx,
      threshold: threshold,
      featId: featId
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as InputNode;
    return {
      "id": assembleField(data.nodeId, "nodeId", data.paramRefs),
      "type": "input",
      "threshold": assembleField(data.threshold, "threshold", data.paramRefs),
      "feat_id": assembleField(data.featId, "featId", data.paramRefs)
    };
  }
}

class GateNode extends NodeObject {
  String nodeId;
  int idx;
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  String get nodeType => "gate_node";

  GateNode({
    this.nodeId = "",
    this.idx = 0,
    this.gate,
    this.in1Idx,
    this.in2Idx
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
      case "idx": idx = int.tryParse(text) ?? 0;
      case "in1Idx": in1Idx = int.tryParse(text);
      case "in2Idx": in2Idx = int.tryParse(text);
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
      "nodeId" => nodeId,
      "idx" => idx.toString(),
      "gate" => gate?.name ?? Gate.and.name,
      "in1Idx" => NodeObject.formatNullable(in1Idx),
      "in2Idx" => NodeObject.formatNullable(in2Idx),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final paramRefs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", paramRefs);
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
    final data = GateNode(
      nodeId: nodeId,
      idx: idx,
      gate: gate,
      in1Idx: in1Idx,
      in2Idx: in2Idx
    );
    data.paramRefs.addAll(paramRefs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as GateNode;
    return {
      "id": assembleField(data.nodeId, "nodeId", data.paramRefs),
      "type": "gate",
      "gate": assembleField(data.gate?.toJson(), "gate", data.paramRefs),
      "in1_idx": assembleField(data.in1Idx, "in1Idx", data.paramRefs),
      "in2_idx": assembleField(data.in2Idx, "in2Idx", data.paramRefs)
    };
  }
}

class BranchNode extends NodeObject {
  String nodeId;
  int idx;
  double? threshold;
  String? featId;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "branch_node";

  BranchNode({
    this.nodeId = "",
    this.idx = 0,
    this.threshold,
    this.featId,
    this.trueIdx,
    this.falseIdx
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
      case "idx": idx = int.tryParse(text) ?? 0;
      case "threshold": threshold = double.tryParse(text);
      case "featId": featId = text.isEmpty ? null : text;
      case "trueIdx": trueIdx = int.tryParse(text);
      case "falseIdx": falseIdx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "nodeId" => nodeId,
      "idx" => idx.toString(),
      "threshold" => NodeObject.formatNullable(threshold),
      "featId" => NodeObject.formatNullable(featId),
      "trueIdx" => NodeObject.formatNullable(trueIdx),
      "falseIdx" => NodeObject.formatNullable(falseIdx),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final paramRefs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", paramRefs);
    final threshold = nullDoubleOrDefault(json, "threshold", "threshold", paramRefs);
    final featId = nullStringOrDefault(json, "feat_id", "featId", paramRefs);
    final trueIdx = nullIntOrDefault(json, "true_idx", "trueIdx", paramRefs);
    final falseIdx = nullIntOrDefault(json, "false_idx", "falseIdx", paramRefs);
    
    final data = BranchNode(
      nodeId: nodeId,
      idx: idx,
      threshold: threshold,
      featId: featId,
      trueIdx: trueIdx,
      falseIdx: falseIdx
    );
    data.paramRefs.addAll(paramRefs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as BranchNode;
    return {
      "id": assembleField(data.nodeId, "nodeId", data.paramRefs),
      "type": "branch",
      "threshold": assembleField(data.threshold, "threshold", data.paramRefs),
      "feat_id": assembleField(data.featId, "featId", data.paramRefs),
      "true_idx": assembleField(data.trueIdx, "trueIdx", data.paramRefs),
      "false_idx": assembleField(data.falseIdx, "falseIdx", data.paramRefs)
    };
  }
}

class RefNode extends NodeObject {
  String nodeId;
  int idx;
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "ref_node";

  RefNode({
    this.nodeId = "",
    this.idx = 0,
    this.refIdx,
    this.trueIdx,
    this.falseIdx
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
      case "idx": idx = int.tryParse(text) ?? 0;
      case "refIdx": refIdx = int.tryParse(text);
      case "trueIdx": trueIdx = int.tryParse(text);
      case "falseIdx": falseIdx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "nodeId" => nodeId,
      "idx" => idx.toString(),
      "refIdx" => NodeObject.formatNullable(refIdx),
      "trueIdx" => NodeObject.formatNullable(trueIdx),
      "falseIdx" => NodeObject.formatNullable(falseIdx),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int idx) {
    final refs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", refs);
    final refIdx = nullIntOrDefault(json, "ref_idx", "refIdx", refs);
    final trueIdx = nullIntOrDefault(json, "true_idx", "trueIdx", refs);
    final falseIdx = nullIntOrDefault(json, "false_idx", "falseIdx", refs);
    final data = RefNode(
      nodeId: nodeId,
      idx: idx,
      refIdx: refIdx,
      trueIdx: trueIdx,
      falseIdx: falseIdx
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as RefNode;
    return {
      "id": assembleField(data.nodeId, "nodeId", data.paramRefs),
      "type": "ref",
      "ref_idx": assembleField(data.refIdx, "refIdx", data.paramRefs),
      "true_idx": assembleField(data.trueIdx, "trueIdx", data.paramRefs),
      "false_idx": assembleField(data.falseIdx, "falseIdx", data.paramRefs)
    };
  }
}

class LogicNet extends NodeObject {
  List<String> nodeIds;
  List<String> nodeSelection;
  bool defaultValue;

  @override
  String get nodeType => "logic_net";

  LogicNet({
    this.nodeIds = const [],
    this.nodeSelection = const [],
    this.defaultValue = false
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeSelection": nodeSelection = NodeObject.parseStringList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "defaultValue": defaultValue = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "nodeSelection" => NodeObject.formatList(nodeSelection),
      "defaultValue" => defaultValue.toString(),
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
    final nodeSelection = stringListOrDefault(json, "node_selection", "nodeSelection", const [], refs);
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
  List<String> nodeSelection;
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

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeSelection": nodeSelection = NodeObject.parseStringList(text);
      case "maxTrailLen": maxTrailLen = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "defaultValue": defaultValue = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "nodeSelection" => NodeObject.formatList(nodeSelection),
      "maxTrailLen" => maxTrailLen.toString(),
      "defaultValue" => defaultValue.toString(),
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
    final nodeSelection = stringListOrDefault(json, "node_selection", "nodeSelection", const [], paramRefs);
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

  @override
  void updateField(String fieldKey, String text) {
    final val = double.tryParse(text) ?? 0.0;
    switch (fieldKey) {
      case "node": node = val;
      case "input": input = val;
      case "gate": gate = val;
      case "recurrence": recurrence = val;
      case "feedforward": feedforward = val;
      case "usedFeat": usedFeat = val;
      case "unusedFeat": unusedFeat = val;
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
      "usedFeat" => usedFeat.toString(),
      "unusedFeat" => unusedFeat.toString(),
      _ => ""
    };
  }

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

  @override
  void updateField(String fieldKey, String text) {
    final val = double.tryParse(text) ?? 0.0;
    switch (fieldKey) {
      case "node": node = val;
      case "branch": branch = val;
      case "ref": ref = val;
      case "leaf": leaf = val;
      case "nonLeaf": nonLeaf = val;
      case "usedFeat": usedFeat = val;
      case "unusedFeat": unusedFeat = val;
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
      "nonLeaf" => nonLeaf.toString(),
      "usedFeat" => usedFeat.toString(),
      "unusedFeat" => unusedFeat.toString(),
      _ => ""
    };
  }

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
  const NodePtrContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "anchor", paramType: ParamType.stringType, child: NodeDropdown<Anchor>(
          label: "anchor", fieldKey: "anchor", options: Anchor.values, labelFor: (val) => val.name
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "idx", paramType: ParamType.intType, child: NodeTextField(label: "idx", fieldKey: "idx"))
      ]
    );
  }
}

class InputNodeContent extends StatelessWidget {
  const InputNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        SizedBox(height: 2),
        NodeTextField(label: "idx", fieldKey: "idx"),
        SizedBox(height: 2),
        ParamField(fieldKey: "featId", paramType: ParamType.stringType, child: NodeTextField(label: "featId", fieldKey: "featId")),
        SizedBox(height: 2),
        ParamField(fieldKey: "threshold", paramType: ParamType.floatType, child: NodeTextField(label: "threshold", fieldKey: "threshold"))
      ]
    );
  }
}

class GateNodeContent extends StatelessWidget {
  const GateNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        SizedBox(height: 2),
        NodeTextField(label: "idx", fieldKey: "idx"),
        SizedBox(height: 2),
        ParamField(fieldKey: "gate", paramType: ParamType.stringType, child: NodeDropdown<Gate>(
          label: "gate", fieldKey: "gate", options: Gate.values, labelFor: (val) => val.name
        )),
        SizedBox(height: 2),
        ParamField(fieldKey: "in1Idx", paramType: ParamType.intType, child: NodeTextField(label: "in1Idx", fieldKey: "in1Idx")),
        SizedBox(height: 2),
        ParamField(fieldKey: "in2Idx", paramType: ParamType.intType, child: NodeTextField(label: "in2Idx", fieldKey: "in2Idx"))
      ]
    );
  }
}

class BranchNodeContent extends StatelessWidget {
  const BranchNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        SizedBox(height: 2),
        NodeTextField(label: "idx", fieldKey: "idx"),
        SizedBox(height: 2),
        ParamField(fieldKey: "featId", paramType: ParamType.stringType, child: NodeTextField(label: "featId", fieldKey: "featId")),
        SizedBox(height: 2),
        ParamField(fieldKey: "threshold", paramType: ParamType.floatType, child: NodeTextField(label: "threshold", fieldKey: "threshold")),
        SizedBox(height: 2),
        ParamField(fieldKey: "trueIdx", paramType: ParamType.intType, child: NodeTextField(label: "trueIdx", fieldKey: "trueIdx")),
        SizedBox(height: 2),
        ParamField(fieldKey: "falseIdx", paramType: ParamType.intType, child: NodeTextField(label: "falseIdx", fieldKey: "falseIdx"))
      ]
    );
  }
}

class RefNodeContent extends StatelessWidget {
  const RefNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        SizedBox(height: 2),
        NodeTextField(label: "idx", fieldKey: "idx"),
        SizedBox(height: 2),
        ParamField(fieldKey: "refIdx", paramType: ParamType.intType, child: NodeTextField(label: "refIdx", fieldKey: "refIdx")),
        SizedBox(height: 2),
        ParamField(fieldKey: "trueIdx", paramType: ParamType.intType, child: NodeTextField(label: "trueIdx", fieldKey: "trueIdx")),
        SizedBox(height: 2),
        ParamField(fieldKey: "falseIdx", paramType: ParamType.intType, child: NodeTextField(label: "falseIdx", fieldKey: "falseIdx"))
      ]
    );
  }
}

class LogicNetContent extends StatelessWidget {
  const LogicNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeSelection", paramType: ParamType.stringListType, child: NodeTextField(label: "nodeSel", fieldKey: "nodeSelection")),
        SizedBox(height: 2),
        ParamField(fieldKey: "defaultValue", paramType: ParamType.boolType, child: NodeCheckbox(label: "default", fieldKey: "defaultValue"))
      ]
    );
  }
}

class DecisionNetContent extends StatelessWidget {
  const DecisionNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeSelection", paramType: ParamType.stringListType, child: NodeTextField(label: "nodeSel", fieldKey: "nodeSelection")),
        SizedBox(height: 2),
        ParamField(fieldKey: "maxTrailLen", paramType: ParamType.intType, child: NodeTextField(label: "maxTrail", fieldKey: "maxTrailLen")),
        SizedBox(height: 2),
        ParamField(fieldKey: "defaultValue", paramType: ParamType.boolType, child: NodeCheckbox(label: "default", fieldKey: "defaultValue"))
      ]
    );
  }
}

class LogicPenaltiesContent extends StatelessWidget {
  const LogicPenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "node", paramType: ParamType.floatType, child: NodeTextField(label: "node", fieldKey: "node")),
        SizedBox(height: 2),
        ParamField(fieldKey: "input", paramType: ParamType.floatType, child: NodeTextField(label: "input", fieldKey: "input")),
        SizedBox(height: 2),
        ParamField(fieldKey: "gate", paramType: ParamType.floatType, child: NodeTextField(label: "gate", fieldKey: "gate")),
        SizedBox(height: 2),
        ParamField(fieldKey: "recurrence", paramType: ParamType.floatType, child: NodeTextField(label: "recurrence", fieldKey: "recurrence")),
        SizedBox(height: 2),
        ParamField(fieldKey: "feedforward", paramType: ParamType.floatType, child: NodeTextField(label: "feedfwd", fieldKey: "feedforward")),
        SizedBox(height: 2),
        ParamField(fieldKey: "usedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "usedFeat", fieldKey: "usedFeat")),
        SizedBox(height: 2),
        ParamField(fieldKey: "unusedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "unusedFeat", fieldKey: "unusedFeat"))
      ]
    );
  }
}

class DecisionPenaltiesContent extends StatelessWidget {
  const DecisionPenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "node", paramType: ParamType.floatType, child: NodeTextField(label: "node", fieldKey: "node")),
        SizedBox(height: 2),
        ParamField(fieldKey: "branch", paramType: ParamType.floatType, child: NodeTextField(label: "branch", fieldKey: "branch")),
        SizedBox(height: 2),
        ParamField(fieldKey: "ref", paramType: ParamType.floatType, child: NodeTextField(label: "ref", fieldKey: "ref")),
        SizedBox(height: 2),
        ParamField(fieldKey: "leaf", paramType: ParamType.floatType, child: NodeTextField(label: "leaf", fieldKey: "leaf")),
        SizedBox(height: 2),
        ParamField(fieldKey: "nonLeaf", paramType: ParamType.floatType, child: NodeTextField(label: "nonLeaf", fieldKey: "nonLeaf")),
        SizedBox(height: 2),
        ParamField(fieldKey: "usedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "usedFeat", fieldKey: "usedFeat")),
        SizedBox(height: 2),
        ParamField(fieldKey: "unusedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "unusedFeat", fieldKey: "unusedFeat"))
      ]
    );
  }
}
