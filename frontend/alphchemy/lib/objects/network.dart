import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
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
  double? threshold;
  String? featId;

  @override
  String get nodeType => "input_node";

  InputNode({
    this.nodeId = "",
    this.threshold,
    this.featId
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
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
      "threshold" => NodeObject.formatNullable(threshold),
      "featId" => NodeObject.formatNullable(featId),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", refs);
    final threshold = nullDoubleOrDefault(json, "threshold", "threshold", refs);
    final featId = nullStringOrDefault(json, "feat_id", "featId", refs);
    final data = InputNode(
      nodeId: nodeId,
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
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  String get nodeType => "gate_node";

  GateNode({
    this.nodeId = "",
    this.gate,
    this.in1Idx,
    this.in2Idx
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
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
      "gate" => gate?.name ?? Gate.and.name,
      "in1Idx" => NodeObject.formatNullable(in1Idx),
      "in2Idx" => NodeObject.formatNullable(in2Idx),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
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
  double? threshold;
  String? featId;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "branch_node";

  BranchNode({
    this.nodeId = "",
    this.threshold,
    this.featId,
    this.trueIdx,
    this.falseIdx
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
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

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", paramRefs);
    final threshold = nullDoubleOrDefault(json, "threshold", "threshold", paramRefs);
    final featId = nullStringOrDefault(json, "feat_id", "featId", paramRefs);
    final trueIdx = nullIntOrDefault(json, "true_idx", "trueIdx", paramRefs);
    final falseIdx = nullIntOrDefault(json, "false_idx", "falseIdx", paramRefs);

    final data = BranchNode(
      nodeId: nodeId,
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
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => "ref_node";

  RefNode({
    this.nodeId = "",
    this.refIdx,
    this.trueIdx,
    this.falseIdx
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "nodeId": nodeId = text;
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
      "refIdx" => NodeObject.formatNullable(refIdx),
      "trueIdx" => NodeObject.formatNullable(trueIdx),
      "falseIdx" => NodeObject.formatNullable(falseIdx),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final nodeId = stringOrDefault(json, "id", "nodeId", "", refs);
    final refIdx = nullIntOrDefault(json, "ref_idx", "refIdx", refs);
    final trueIdx = nullIntOrDefault(json, "true_idx", "trueIdx", refs);
    final falseIdx = nullIntOrDefault(json, "false_idx", "falseIdx", refs);
    final data = RefNode(
      nodeId: nodeId,
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
  List<String> nodeSelection;
  bool defaultValue;

  @override
  String get nodeType => "logic_net";

  LogicNet({
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
    final childIds = <String>[];
    final rawNodes = json["node_pool"] as List<dynamic>?;
    if (rawNodes != null) {
      for (final rawNode in rawNodes) {
        final map = rawNode as Map<String, dynamic>;
        final childId = LogicNet.flattenNode(ctx, map);
        childIds.add(childId);
      }
    }
    final refs = <String, String>{};
    final nodeSelection = stringListOrDefault(json, "node_selection", "nodeSelection", const [], refs);
    final defaultValue = boolOrDefault(json, "default_value", "defaultValue", false, refs);
    final data = LogicNet(
      nodeSelection: nodeSelection,
      defaultValue: defaultValue
    );
    data.paramRefs.addAll(refs);
    final parentId = ctx.addNode(data);
    for (final childId in childIds) {
      ctx.connect(parentId, "out_nodes", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as LogicNet;
    final childNodeIds = ctx.childIds(nodeId, "out_nodes");
    final nodesList = childNodeIds.map((id) {
      return LogicNet.assembleNode(ctx, id);
    }).toList();
    return {
      "node_pool": nodesList,
      "node_selection": assembleField(data.nodeSelection, "nodeSelection", data.paramRefs),
      "default_value": assembleField(data.defaultValue, "defaultValue", data.paramRefs)
    };
  }

  static String flattenNode(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"] as String;
    if (type == "input") {
      return InputNode.flatten(ctx, json);
    } else if (type == "gate") {
      return GateNode.flatten(ctx, json);
    }
    throw Exception("Unknown node type: $type");
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
  List<String> nodeSelection;
  int maxTrailLen;
  bool defaultValue;

  @override
  String get nodeType => "decision_net";

  DecisionNet({
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
    final childIds = <String>[];
    final rawNodes = json["node_pool"] as List<dynamic>?;
    if (rawNodes != null) {
      for (final rawNode in rawNodes) {
        final map = rawNode as Map<String, dynamic>;
        final childId = DecisionNet.flattenNode(ctx, map);
        childIds.add(childId);
      }
    }

    final paramRefs = <String, String>{};
    final nodeSelection = stringListOrDefault(json, "node_selection", "nodeSelection", const [], paramRefs);
    final maxTrailLen = intOrDefault(json, "max_trail_len", "maxTrailLen", 10, paramRefs);
    final defaultValue = boolOrDefault(json, "default_value", "defaultValue", false, paramRefs);
    final data = DecisionNet(
      nodeSelection: nodeSelection,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue
    );
    data.paramRefs.addAll(paramRefs);
    final parentId = ctx.addNode(data);
    for (final childId in childIds) {
      ctx.connect(parentId, "out_nodes", childId);
    }
    return parentId;
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as DecisionNet;
    final childNodeIds = ctx.childIds(nodeId, "out_nodes");
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

  static String flattenNode(FlattenContext ctx, Map<String, dynamic> json) {
    final type = json["type"] as String;
    if (type == "branch") {
      return BranchNode.flatten(ctx, json);
    }
    return RefNode.flatten(ctx, json);
  }

  static Map<String, dynamic> assembleNode(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    if (node.data is BranchNode) {
      return BranchNode.assemble(ctx, nodeId);
    }
    return RefNode.assemble(ctx, nodeId);
  }
}

class NetworkGen extends NodeObject {
  String type;

  @override
  String get nodeType => "network_gen";

  NetworkGen({this.type = "logic"});

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
    final data = NetworkGen(type: type);
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

class PenaltiesGen extends NodeObject {
  String type;

  @override
  String get nodeType => "penalties_gen";

  PenaltiesGen({this.type = "logic"});

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
    final data = PenaltiesGen(type: type);
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
