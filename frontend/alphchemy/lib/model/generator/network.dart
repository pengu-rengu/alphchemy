import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/utils.dart";

enum Anchor {
  fromStart,
  fromEnd;

  static Anchor fromJson(dynamic value) {
    switch (castStr(value)) {
      case "from_start":
        return Anchor.fromStart;
      case "from_end":
        return Anchor.fromEnd;
      default:
        throw ArgumentError("Invalid Anchor: $value");
    }
  }

  String toJson() {
    switch (this) {
      case Anchor.fromStart:
        return "from_start";
      case Anchor.fromEnd:
        return "from_end";
    }
  }
}

enum Gate {
  and,
  or,
  xor,
  nand,
  nor,
  xnor;

  static Gate fromJson(dynamic value) {
    switch (castStr(value)) {
      case "and":
        return Gate.and;
      case "or":
        return Gate.or;
      case "xor":
        return Gate.xor;
      case "nand":
        return Gate.nand;
      case "nor":
        return Gate.nor;
      case "xnor":
        return Gate.xnor;
      default:
        throw ArgumentError("Invalid gate: $value");
    }
  }

  static List<Gate> listFromJson(dynamic value) {
    final values = (value as List<dynamic>).map((item) => item as String);
    return values.map(Gate.fromJson).toList();
  }

  String toJson() {
    return name;
  }
}

class NodePtr extends NodeData {
  Anchor anchor;
  int idx;

  @override
  NodeType get nodeType => NodeType.nodePtr;

  @override
  int get fieldCount => 2;

  NodePtr({this.anchor = Anchor.fromStart, this.idx = 0, super.paramRefs});

  factory NodePtr.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final anchor = getField<Anchor>(json, "anchor", Anchor.fromStart, paramRefs, Anchor.fromJson);
    final idx = getField<int>(json, "idx", 0, paramRefs);

    return NodePtr(anchor: anchor, idx: idx, paramRefs: paramRefs);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "idx":
        idx = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "anchor":
        anchor = value as Anchor;
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

  @override
  Map<String, dynamic> toJson() {
    final anchorJson = assembleField("anchor", anchor.toJson());
    final idxJson = assembleField("idx", idx);

    return {
      "anchor": anchorJson,
      "idx": idxJson
    };
  }
}

class InputNode extends NodeData {
  String id;
  double? threshold;
  String? featId;

  @override
  NodeType get nodeType => NodeType.inputNode;

  @override
  int get fieldCount => 3;

  InputNode({this.id = "", this.threshold, this.featId, super.paramRefs});

  factory InputNode.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final threshold = getField<double?>(json, "threshold", null, paramRefs, doubleFromJson);
    final featId = getField<String?>(json, "feat_id", null, paramRefs);

    return InputNode(
      id: id,
      threshold: threshold,
      featId: featId,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "threshold":
        threshold = double.tryParse(text);
      case "feat_id":
        featId = text.isEmpty ? null : text;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "threshold" => threshold?.toString() ?? "",
      "feat_id" => featId ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final thresholdJson = assembleField("threshold", threshold);
    final featIdJson = assembleField("feat_id", featId);

    return {
      "id": idJson,
      "type": "input",
      "threshold": thresholdJson,
      "feat_id": featIdJson
    };
  }
}

class GateNode extends NodeData {
  String id;
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  NodeType get nodeType => NodeType.gateNode;

  @override
  int get fieldCount => 4;

  GateNode({this.id = "", this.gate, this.in1Idx, this.in2Idx, super.paramRefs});

  factory GateNode.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final gate = getField<Gate?>(json, "gate", null, paramRefs, Gate.fromJson);
    final in1Idx = getField<int?>(json, "in1_idx", null, paramRefs);
    final in2Idx = getField<int?>(json, "in2_idx", null, paramRefs);

    return GateNode(
      id: id,
      gate: gate,
      in1Idx: in1Idx,
      in2Idx: in2Idx,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "in1_idx":
        in1Idx = int.tryParse(text);
      case "in2_idx":
        in2Idx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "gate":
        gate = value as Gate;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "gate" => gate?.name ?? "",
      "in1_idx" => in1Idx?.toString() ?? "",
      "in2_idx" => in2Idx?.toString() ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final gateJson = assembleField("gate", gate?.toJson());
    final in1IdxJson = assembleField("in1_idx", in1Idx);
    final in2IdxJson = assembleField("in2_idx", in2Idx);

    return {
      "id": idJson,
      "type": "gate",
      "gate": gateJson,
      "in1_idx": in1IdxJson,
      "in2_idx": in2IdxJson
    };
  }
}

class BranchNode extends NodeData {
  String id;
  double? threshold;
  String? featId;
  int? trueIdx;
  int? falseIdx;

  @override
  NodeType get nodeType => NodeType.branchNode;

  @override
  int get fieldCount => 5;

  BranchNode({
    this.id = "",
    this.threshold,
    this.featId,
    this.trueIdx,
    this.falseIdx,
    super.paramRefs
  });

  factory BranchNode.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final threshold = getField<double?>(json, "threshold", null, paramRefs, doubleFromJson);
    final featId = getField<String?>(json, "feat_id", null, paramRefs);
    final trueIdx = getField<int?>(json, "true_idx", null, paramRefs);
    final falseIdx = getField<int?>(json, "false_idx", null, paramRefs);

    return BranchNode(
      id: id,
      threshold: threshold,
      featId: featId,
      trueIdx: trueIdx,
      falseIdx: falseIdx,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "threshold":
        threshold = double.tryParse(text);
      case "feat_id":
        featId = text.isEmpty ? null : text;
      case "true_idx":
        trueIdx = int.tryParse(text);
      case "false_idx":
        falseIdx = int.tryParse(text);
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "threshold" => threshold?.toString() ?? "",
      "feat_id" => featId ?? "",
      "true_idx" => trueIdx?.toString() ?? "",
      "false_idx" => falseIdx?.toString() ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final thresholdJson = assembleField("threshold", threshold);
    final featIdJson = assembleField("feat_id", featId);
    final trueIdxJson = assembleField("true_idx", trueIdx);
    final falseIdxJson = assembleField("false_idx", falseIdx);

    return {
      "id": idJson,
      "type": "branch",
      "threshold": thresholdJson,
      "feat_id": featIdJson,
      "true_idx": trueIdxJson,
      "false_idx": falseIdxJson
    };
  }
}

class RefNode extends NodeData {
  String id;
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  NodeType get nodeType => NodeType.refNode;

  @override
  int get fieldCount => 4;

  RefNode({this.id = "", this.refIdx, this.trueIdx, this.falseIdx, super.paramRefs});

  factory RefNode.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final refIdx = getField<int?>(json, "ref_idx", null, paramRefs);
    final trueIdx = getField<int?>(json, "true_idx", null, paramRefs);
    final falseIdx = getField<int?>(json, "false_idx", null, paramRefs);

    return RefNode(
      id: id,
      refIdx: refIdx,
      trueIdx: trueIdx,
      falseIdx: falseIdx,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "ref_idx":
        refIdx = int.tryParse(text);
      case "true_idx":
        trueIdx = int.tryParse(text);
      case "false_idx":
        falseIdx = int.tryParse(text);
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "ref_idx" => refIdx?.toString() ?? "",
      "true_idx" => trueIdx?.toString() ?? "",
      "false_idx" => falseIdx?.toString() ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final refIdxJson = assembleField("ref_idx", refIdx);
    final trueIdxJson = assembleField("true_idx", trueIdx);
    final falseIdxJson = assembleField("false_idx", falseIdx);

    return {
      "id": idJson,
      "type": "ref",
      "ref_idx": refIdxJson,
      "true_idx": trueIdxJson,
      "false_idx": falseIdxJson
    };
  }
}

class LogicNet extends NodeData {
  List<String> nodeSelection;
  bool defaultValue;
  List<NodeData> nodes;

  @override
  NodeType get nodeType => NodeType.logicNet;

  @override
  int get fieldCount => 2;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "nodes", label: "Node", multi: true, allowedTypes: [NodeType.inputNode, NodeType.gateNode])
    ];
  }

  LogicNet({
    this.nodeSelection = const [],
    this.defaultValue = false,
    List<NodeData>? nodes,
    super.paramRefs
  }) : nodes = nodes ?? <NodeData>[];

  factory LogicNet.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final nodeSelection = getField<List<String>>(json, "node_selection", const [], paramRefs, listFromJson<String>);
    final defaultValue = getField<bool>(json, "default_value", false, paramRefs);
    final nodes = <NodeData>[];
    final nodesJson = json["node_pool"] as List<dynamic>? ?? [];

    for (final nodeJson in nodesJson) {
      final node = LogicNet.nodeFromJson(nodeJson as Map<String, dynamic>);
      nodes.add(node);
    }

    return LogicNet(
      nodeSelection: nodeSelection,
      defaultValue: defaultValue,
      nodes: nodes,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    if (slotKey != "nodes") return const [];
    return nodes;
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    if (slotKey != "nodes") return false;
    nodes.add(child);
    return true;
  }

  @override
  bool removeDirectChild(String targetId) {
    return removeChildFromList(nodes, targetId);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "node_selection":
        nodeSelection = parseList(text);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "default_value":
        defaultValue = value as bool;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "node_selection" => nodeSelection.join(", "),
      "default_value" => defaultValue.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final nodePool = nodes.map((node) => node.toJson()).toList();
    final nodeSelectionJson = assembleField("node_selection", nodeSelection);
    final defaultValueJson = assembleField("default_value", defaultValue);

    return {
      "node_pool": nodePool,
      "node_selection": nodeSelectionJson,
      "default_value": defaultValueJson
    };
  }

  static NodeData nodeFromJson(Map<String, dynamic> json) {
    final type = json["type"];

    return switch (type) {
      "input" => InputNode.fromJson(json),
      "gate" => GateNode.fromJson(json),
      _ => throw Exception("Unknown logic node type: $type")
    };
  }
}

class DecisionNet extends NodeData {
  List<String> nodeSelection;
  int maxTrailLen;
  bool defaultValue;
  List<NodeData> nodes;

  @override
  NodeType get nodeType => NodeType.decisionNet;

  @override
  int get fieldCount => 3;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "nodes", label: "Node", multi: true, allowedTypes: [NodeType.branchNode, NodeType.refNode])
    ];
  }

  DecisionNet({
    this.nodeSelection = const [],
    this.maxTrailLen = 1,
    this.defaultValue = false,
    List<NodeData>? nodes,
    super.paramRefs
  }) : nodes = nodes ?? <NodeData>[];

  factory DecisionNet.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final nodeSelection = getField<List<String>>(json, "node_selection", const [], paramRefs, listFromJson<String>);
    final maxTrailLen = getField<int>(json, "max_trail_len", 10, paramRefs);
    final defaultValue = getField<bool>(json, "default_value", false, paramRefs);
    final nodes = <NodeData>[];
    final nodesJson = json["node_pool"] as List<dynamic>? ?? [];

    for (final nodeJson in nodesJson) {
      final node = DecisionNet.nodeFromJson(nodeJson as Map<String, dynamic>);
      nodes.add(node);
    }

    return DecisionNet(
      nodeSelection: nodeSelection,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue,
      nodes: nodes,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    if (slotKey != "nodes") return const [];
    return nodes;
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    if (slotKey != "nodes") return false;
    nodes.add(child);
    return true;
  }

  @override
  bool removeDirectChild(String targetId) {
    return removeChildFromList(nodes, targetId);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "node_selection":
        nodeSelection = parseList(text);
      case "max_trail_len":
        maxTrailLen = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "default_value":
        defaultValue = value as bool;
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

  @override
  Map<String, dynamic> toJson() {
    final nodePool = nodes.map((node) => node.toJson()).toList();
    final nodeSelectionJson = assembleField("node_selection", nodeSelection);
    final maxTrailLenJson = assembleField("max_trail_len", maxTrailLen);
    final defaultValueJson = assembleField("default_value", defaultValue);

    return {
      "node_pool": nodePool,
      "node_selection": nodeSelectionJson,
      "max_trail_len": maxTrailLenJson,
      "default_value": defaultValueJson
    };
  }

  static NodeData nodeFromJson(Map<String, dynamic> json) {
    final type = json["type"];

    return switch (type) {
      "branch" => BranchNode.fromJson(json),
      "ref" => RefNode.fromJson(json),
      _ => throw Exception("Unknown decision node type: $type")
    };
  }
}

class Network extends NodeData {
  String type;
  LogicNet? logicNet;
  DecisionNet? decisionNet;

  @override
  NodeType get nodeType => NodeType.networkGen;

  @override
  int get fieldCount => 1;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "logic_net", label: "Logic Net", multi: false, allowedTypes: [NodeType.logicNet]),
      ChildSlot(key: "decision_net", label: "Decision Net", multi: false, allowedTypes: [NodeType.decisionNet])
    ];
  }

  Network({this.type = "logic", this.logicNet, this.decisionNet, super.paramRefs});

  factory Network.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final type = getField<String>(json, "type", "logic", paramRefs);
    final logicNetJson = json["logic_net"] as Map<String, dynamic>?;
    final decisionNetJson = json["decision_net"] as Map<String, dynamic>?;
    final logicNet = logicNetJson == null ? null : LogicNet.fromJson(logicNetJson);
    final decisionNet = decisionNetJson == null ? null : DecisionNet.fromJson(decisionNetJson);

    return Network(
      type: type,
      logicNet: logicNet,
      decisionNet: decisionNet,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "logic_net":
        return logicNet == null ? const [] : [logicNet!];
      case "decision_net":
        return decisionNet == null ? const [] : [decisionNet!];
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "logic_net":
        logicNet = child as LogicNet;
        return true;
      case "decision_net":
        decisionNet = child as DecisionNet;
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (logicNet?.nodeId == targetId) {
      logicNet = null;
      return true;
    }

    if (decisionNet?.nodeId == targetId) {
      decisionNet = null;
      return true;
    }

    return false;
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "type":
        type = value as String;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "type" => type,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final typeJson = assembleField("type", type);

    return {
      "type": typeJson,
      "logic_net": logicNet?.toJson(),
      "decision_net": decisionNet?.toJson()
    };
  }
}

class LogicPenalties extends NodeData {
  double node;
  double input;
  double gate;
  double recurrence;
  double feedforward;
  double usedFeat;
  double unusedFeat;

  @override
  NodeType get nodeType => NodeType.logicPenalties;

  @override
  int get fieldCount => 7;

  LogicPenalties({
    this.node = 0.0,
    this.input = 0.0,
    this.gate = 0.0,
    this.recurrence = 0.0,
    this.feedforward = 0.0,
    this.usedFeat = 0.0,
    this.unusedFeat = 0.0,
    super.paramRefs
  });

  factory LogicPenalties.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final node = getField<double>(json, "node", 0.0, paramRefs, doubleFromJson);
    final input = getField<double>(json, "input", 0.0, paramRefs, doubleFromJson);
    final gate = getField<double>(json, "gate", 0.0, paramRefs, doubleFromJson);
    final recurrence = getField<double>(json, "recurrence", 0.0, paramRefs, doubleFromJson);
    final feedforward = getField<double>(json, "feedforward", 0.0, paramRefs, doubleFromJson);
    final usedFeat = getField<double>(json, "used_feat", 0.0, paramRefs, doubleFromJson);
    final unusedFeat = getField<double>(json, "unused_feat", 0.0, paramRefs, doubleFromJson);

    return LogicPenalties(
      node: node,
      input: input,
      gate: gate,
      recurrence: recurrence,
      feedforward: feedforward,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    final value = double.tryParse(text) ?? 0.0;

    switch (fieldKey) {
      case "node":
        node = value;
      case "input":
        input = value;
      case "gate":
        gate = value;
      case "recurrence":
        recurrence = value;
      case "feedforward":
        feedforward = value;
      case "used_feat":
        usedFeat = value;
      case "unused_feat":
        unusedFeat = value;
    }
  }

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

  @override
  Map<String, dynamic> toJson() {
    final nodeJson = assembleField("node", node);
    final inputJson = assembleField("input", input);
    final gateJson = assembleField("gate", gate);
    final recurrenceJson = assembleField("recurrence", recurrence);
    final feedforwardJson = assembleField("feedforward", feedforward);
    final usedFeatJson = assembleField("used_feat", usedFeat);
    final unusedFeatJson = assembleField("unused_feat", unusedFeat);

    return {
      "node": nodeJson,
      "input": inputJson,
      "gate": gateJson,
      "recurrence": recurrenceJson,
      "feedforward": feedforwardJson,
      "used_feat": usedFeatJson,
      "unused_feat": unusedFeatJson
    };
  }
}

class DecisionPenalties extends NodeData {
  double node;
  double branch;
  double ref;
  double leaf;
  double nonLeaf;
  double usedFeat;
  double unusedFeat;

  @override
  NodeType get nodeType => NodeType.decisionPenalties;

  @override
  int get fieldCount => 7;

  DecisionPenalties({
    this.node = 0.0,
    this.branch = 0.0,
    this.ref = 0.0,
    this.leaf = 0.0,
    this.nonLeaf = 0.0,
    this.usedFeat = 0.0,
    this.unusedFeat = 0.0,
    super.paramRefs
  });

  factory DecisionPenalties.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final node = getField<double>(json, "node", 0.0, paramRefs, doubleFromJson);
    final branch = getField<double>(json, "branch", 0.0, paramRefs, doubleFromJson);
    final ref = getField<double>(json, "ref", 0.0, paramRefs, doubleFromJson);
    final leaf = getField<double>(json, "leaf", 0.0, paramRefs, doubleFromJson);
    final nonLeaf = getField<double>(json, "non_leaf", 0.0, paramRefs, doubleFromJson);
    final usedFeat = getField<double>(json, "used_feat", 0.0, paramRefs, doubleFromJson);
    final unusedFeat = getField<double>(json, "unused_feat", 0.0, paramRefs, doubleFromJson);

    return DecisionPenalties(
      node: node,
      branch: branch,
      ref: ref,
      leaf: leaf,
      nonLeaf: nonLeaf,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    final value = double.tryParse(text) ?? 0.0;

    switch (fieldKey) {
      case "node":
        node = value;
      case "branch":
        branch = value;
      case "ref":
        ref = value;
      case "leaf":
        leaf = value;
      case "non_leaf":
        nonLeaf = value;
      case "used_feat":
        usedFeat = value;
      case "unused_feat":
        unusedFeat = value;
    }
  }

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

  @override
  Map<String, dynamic> toJson() {
    final nodeJson = assembleField("node", node);
    final branchJson = assembleField("branch", branch);
    final refJson = assembleField("ref", ref);
    final leafJson = assembleField("leaf", leaf);
    final nonLeafJson = assembleField("non_leaf", nonLeaf);
    final usedFeatJson = assembleField("used_feat", usedFeat);
    final unusedFeatJson = assembleField("unused_feat", unusedFeat);

    return {
      "node": nodeJson,
      "branch": branchJson,
      "ref": refJson,
      "leaf": leafJson,
      "non_leaf": nonLeafJson,
      "used_feat": usedFeatJson,
      "unused_feat": unusedFeatJson
    };
  }
}

class Penalties extends NodeData {
  String type;
  LogicPenalties? logicPenalties;
  DecisionPenalties? decisionPenalties;

  @override
  NodeType get nodeType => NodeType.penaltiesGen;

  @override
  int get fieldCount => 1;

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(key: "logic_penalties", label: "Logic Penalties", multi: false, allowedTypes: [NodeType.logicPenalties]),
      ChildSlot(key: "decision_penalties", label: "Decision Penalties", multi: false, allowedTypes: [NodeType.decisionPenalties])
    ];
  }

  Penalties({this.type = "logic", this.logicPenalties, this.decisionPenalties, super.paramRefs});

  factory Penalties.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final type = getField<String>(json, "type", "logic", paramRefs);
    final logicJson = json["logic_penalties"] as Map<String, dynamic>?;
    final decisionJson = json["decision_penalties"] as Map<String, dynamic>?;
    final logicPenalties = logicJson == null ? null : LogicPenalties.fromJson(logicJson);
    final decisionPenalties = decisionJson == null ? null : DecisionPenalties.fromJson(decisionJson);

    return Penalties(
      type: type,
      logicPenalties: logicPenalties,
      decisionPenalties: decisionPenalties,
      paramRefs: paramRefs
    );
  }

  @override
  List<NodeData> childrenInSlot(String slotKey) {
    switch (slotKey) {
      case "logic_penalties":
        return logicPenalties == null ? const [] : [logicPenalties!];
      case "decision_penalties":
        return decisionPenalties == null ? const [] : [decisionPenalties!];
      default:
        return const [];
    }
  }

  @override
  bool attachChild(String slotKey, NodeData child) {
    switch (slotKey) {
      case "logic_penalties":
        logicPenalties = child as LogicPenalties;
        return true;
      case "decision_penalties":
        decisionPenalties = child as DecisionPenalties;
        return true;
      default:
        return false;
    }
  }

  @override
  bool removeDirectChild(String targetId) {
    if (logicPenalties?.nodeId == targetId) {
      logicPenalties = null;
      return true;
    }

    if (decisionPenalties?.nodeId == targetId) {
      decisionPenalties = null;
      return true;
    }

    return false;
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "type":
        type = value as String;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "type" => type,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final typeJson = assembleField("type", type);

    return {
      "type": typeJson,
      "logic_penalties": logicPenalties?.toJson(),
      "decision_penalties": decisionPenalties?.toJson()
    };
  }
}
