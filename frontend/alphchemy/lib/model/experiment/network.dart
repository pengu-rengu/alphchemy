import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

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
  List<Widget> get fields => [
    NodeDropdown<Anchor>(
      label: "Anchor",
      field: "anchor",
      options: Anchor.values,
      optionLabel: (option) => option.name
    ),
    const NodeTextField(label: "idx", field: "idx")
  ];

  NodePtr({this.anchor = Anchor.fromStart, this.idx = 0});

  factory NodePtr.fromJson(Map<String, dynamic> json) {
    final anchor = getField<Anchor>(json, "anchor", Anchor.fromStart, Anchor.fromJson);
    final idx = getField<int>(json, "idx", 0);

    return NodePtr(anchor: anchor, idx: idx);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "anchor": anchor.toJson(),
      "idx": idx
    };
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "idx":
        idx = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "anchor":
        anchor = value as Anchor;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "anchor" => anchor.name,
      "idx" => idx.toString(),
      _ => ""
    };
  }
}

class InputNode extends NodeData {
  double? threshold;
  String? featId;

  @override
  NodeType get nodeType => NodeType.inputNode;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "feat_id"),
    NodeTextField(label: "Threshold", field: "threshold")
  ];

  InputNode({this.threshold, this.featId});

  factory InputNode.fromJson(Map<String, dynamic> json) {
    final threshold = getField<double?>(json, "threshold", null, doubleFromJson);
    final featId = getField<String?>(json, "feat_id", null);

    return InputNode(threshold: threshold, featId: featId);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "threshold":
        threshold = double.tryParse(text);
      case "feat_id":
        featId = text.isEmpty ? null : text;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "threshold" => threshold?.toString() ?? "",
      "feat_id" => featId ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "input",
      "threshold": threshold,
      "feat_id": featId
    };
  }
}

class GateNode extends NodeData {
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  NodeType get nodeType => NodeType.gateNode;

  @override
  List<Widget> get fields => const [
    NodeDropdown<Gate>(
      label: "Gate",
      field: "gate",
      options: Gate.values,
      optionLabel: GateNode._gateLabel
    ),
    NodeTextField(label: "in1Idx", field: "in1_idx"),
    NodeTextField(label: "in2Idx", field: "in2_idx")
  ];

  GateNode({this.gate, this.in1Idx, this.in2Idx});

  static String _gateLabel(Gate value) {
    return value.name;
  }

  factory GateNode.fromJson(Map<String, dynamic> json) {
    final gate = getField<Gate?>(json, "gate", null, Gate.fromJson);
    final in1Idx = getField<int?>(json, "in1_idx", null);
    final in2Idx = getField<int?>(json, "in2_idx", null);

    return GateNode(gate: gate, in1Idx: in1Idx, in2Idx: in2Idx);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "in1_idx":
        in1Idx = int.tryParse(text);
      case "in2_idx":
        in2Idx = int.tryParse(text);
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "gate":
        gate = value as Gate;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "gate" => gate?.name ?? "",
      "in1_idx" => in1Idx?.toString() ?? "",
      "in2_idx" => in2Idx?.toString() ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "gate",
      "gate": gate?.toJson(),
      "in1_idx": in1Idx,
      "in2_idx": in2Idx
    };
  }
}

class BranchNode extends NodeData {
  double? threshold;
  String? featId;
  int? trueIdx;
  int? falseIdx;

  @override
  NodeType get nodeType => NodeType.branchNode;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "feat_id"),
    NodeTextField(label: "Threshold", field: "threshold"),
    NodeTextField(label: "True Node Index", field: "true_idx"),
    NodeTextField(label: "False Node Index", field: "false_idx")
  ];

  BranchNode({this.threshold, this.featId, this.trueIdx, this.falseIdx});

  factory BranchNode.fromJson(Map<String, dynamic> json) {
    final threshold = getField<double?>(json, "threshold", null, doubleFromJson);
    final featId = getField<String?>(json, "feat_id", null);
    final trueIdx = getField<int?>(json, "true_idx", null);
    final falseIdx = getField<int?>(json, "false_idx", null);

    return BranchNode(
      threshold: threshold,
      featId: featId,
      trueIdx: trueIdx,
      falseIdx: falseIdx
    );
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
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
  String formatField(String field) {
    return switch (field) {
      "threshold" => threshold?.toString() ?? "",
      "feat_id" => featId ?? "",
      "true_idx" => trueIdx?.toString() ?? "",
      "false_idx" => falseIdx?.toString() ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "branch",
      "threshold": threshold,
      "feat_id": featId,
      "true_idx": trueIdx,
      "false_idx": falseIdx
    };
  }
}

class RefNode extends NodeData {
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  NodeType get nodeType => NodeType.refNode;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Reference Node Index", field: "ref_idx"),
    NodeTextField(label: "True Node Index", field: "true_idx"),
    NodeTextField(label: "False Node Index", field: "false_idx")
  ];

  RefNode({this.refIdx, this.trueIdx, this.falseIdx});

  factory RefNode.fromJson(Map<String, dynamic> json) {
    final refIdx = getField<int?>(json, "ref_idx", null);
    final trueIdx = getField<int?>(json, "true_idx", null);
    final falseIdx = getField<int?>(json, "false_idx", null);

    return RefNode(refIdx: refIdx, trueIdx: trueIdx, falseIdx: falseIdx);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "ref_idx":
        refIdx = int.tryParse(text);
      case "true_idx":
        trueIdx = int.tryParse(text);
      case "false_idx":
        falseIdx = int.tryParse(text);
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "ref_idx" => refIdx?.toString() ?? "",
      "true_idx" => trueIdx?.toString() ?? "",
      "false_idx" => falseIdx?.toString() ?? "",
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "ref",
      "ref_idx": refIdx,
      "true_idx": trueIdx,
      "false_idx": falseIdx
    };
  }
}

sealed class Network extends NodeData {
  bool defaultValue;
  List<NodeData> nodes;

  Network({this.defaultValue = false, List<NodeData>? nodes})
    : nodes = nodes ?? <NodeData>[];

  factory Network.fromJson(Map<String, dynamic> json) {
    final type = json["type"];

    return switch (type) {
      "logic" => LogicNet.fromJson(json),
      "decision" => DecisionNet.fromJson(json),
      _ => throw Exception("Unknown network type: $type")
    };
  }
}

class LogicNet extends Network {
  
  @override
  NodeType get nodeType => NodeType.logicNet;

  @override
  List<Widget> get fields => const [
    NodeBoolDropdown(label: "Default Value", field: "default_value")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "nodes", label: "Nodes", isMulti: true, allowedTypes: [NodeType.inputNode, NodeType.gateNode])
    ];
  }

  LogicNet({super.defaultValue, super.nodes});

  factory LogicNet.fromJson(Map<String, dynamic> json) {
    final defaultValue = getField<bool>(json, "default_value", false);
    final nodes = <NodeData>[];
    final nodesJson = json["nodes"] as List<dynamic>? ?? [];

    for (final nodeJson in nodesJson) {
      final node = LogicNet.nodeFromJson(nodeJson as Map<String, dynamic>);
      nodes.add(node);
    }

    return LogicNet(defaultValue: defaultValue, nodes: nodes);
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    if (field != "nodes") return const [];
    return nodes;
  }

  @override
  bool attachChild(String field, NodeData child) {
    if (field != "nodes") return false;
    nodes.add(child);
    return true;
  }

  @override
  bool removeDirectChild(String targetId) {
    return removeChildFromList(nodes, targetId);
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "default_value":
        defaultValue = value as bool;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "default_value" => defaultValue.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final nodesJson = nodes.map((node) => node.toJson()).toList();

    return {
      "type": "logic",
      "nodes": nodesJson,
      "default_value": defaultValue
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

class DecisionNet extends Network {
  int maxTrailLen;
  @override
  NodeType get nodeType => NodeType.decisionNet;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Max Trail Length", field: "max_trail_len"),
    NodeBoolDropdown(label: "Default Value", field: "default_value")
  ];

  @override
  List<ChildSlot> get childSlots {
    return const [
      ChildSlot(field: "nodes", label: "Nodes", isMulti: true, allowedTypes: [NodeType.branchNode, NodeType.refNode])
    ];
  }

  DecisionNet({super.nodes, super.defaultValue, this.maxTrailLen = 1});

  factory DecisionNet.fromJson(Map<String, dynamic> json) {
    final maxTrailLen = getField<int>(json, "max_trail_len", 10);
    final defaultValue = getField<bool>(json, "default_value", false);
    final nodes = <NodeData>[];
    final nodesJson = json["nodes"] as List<dynamic>? ?? [];

    for (final nodeJson in nodesJson) {
      final node = DecisionNet.nodeFromJson(nodeJson as Map<String, dynamic>);
      nodes.add(node);
    }

    return DecisionNet(maxTrailLen: maxTrailLen, defaultValue: defaultValue, nodes: nodes);
  }

  @override
  List<NodeData> childrenInSlot(String field) {
    if (field != "nodes") return const [];
    return nodes;
  }

  @override
  bool attachChild(String field, NodeData child) {
    if (field != "nodes") return false;
    nodes.add(child);
    return true;
  }

  @override
  bool removeDirectChild(String targetId) {
    return removeChildFromList(nodes, targetId);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "max_trail_len":
        maxTrailLen = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "default_value":
        defaultValue = value as bool;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "max_trail_len" => maxTrailLen.toString(),
      "default_value" => defaultValue.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final nodesJson = nodes.map((node) => node.toJson()).toList();

    return {
      "type": "decision",
      "nodes": nodesJson,
      "max_trail_len": maxTrailLen,
      "default_value": defaultValue
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

sealed class Penalties extends NodeData {
  Penalties();

  factory Penalties.fromJson(Map<String, dynamic> json) {
    final type = json["type"];

    return switch (type) {
      "logic" => LogicPenalties.fromJson(json),
      "decision" => DecisionPenalties.fromJson(json),
      _ => throw Exception("Unknown penalties type: $type")
    };
  }
}

class LogicPenalties extends Penalties {
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
  List<Widget> get fields => const [
    NodeTextField(label: "Node Penalty", field: "node"),
    NodeTextField(label: "Input Node Penalty", field: "input"),
    NodeTextField(label: "Gate Node Penalty", field: "gate"),
    NodeTextField(label: "Recurrent Node Penalty", field: "recurrence"),
    NodeTextField(label: "Feedforward Node Penalty", field: "feedforward"),
    NodeTextField(label: "Used Feature Penalty", field: "used_feat"),
    NodeTextField(label: "Unused Feature Penalty", field: "unused_feat")
  ];

  LogicPenalties({this.node = 0.0, this.input = 0.0, this.gate = 0.0, this.recurrence = 0.0, this.feedforward = 0.0, this.usedFeat = 0.0, this.unusedFeat = 0.0});

  factory LogicPenalties.fromJson(Map<String, dynamic> json) {
    final node = getField<double>(json, "node", 0.0, doubleFromJson);
    final input = getField<double>(json, "input", 0.0, doubleFromJson);
    final gate = getField<double>(json, "gate", 0.0, doubleFromJson);
    final recurrence = getField<double>(json, "recurrence", 0.0, doubleFromJson);
    final feedforward = getField<double>(json, "feedforward", 0.0, doubleFromJson);
    final usedFeat = getField<double>(json, "used_feat", 0.0, doubleFromJson);
    final unusedFeat = getField<double>(json, "unused_feat", 0.0, doubleFromJson);

    return LogicPenalties(
      node: node,
      input: input,
      gate: gate,
      recurrence: recurrence,
      feedforward: feedforward,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat
    );
  }

  @override
  void updateField(String field, String text) {
    final value = double.tryParse(text) ?? 0.0;

    switch (field) {
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
  String formatField(String field) {
    return switch (field) {
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
    return {
      "type": "logic",
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

class DecisionPenalties extends Penalties {
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
  List<Widget> get fields => const [
    NodeTextField(label: "Node Penalty", field: "node"),
    NodeTextField(label: "Branch Node Penalty", field: "branch"),
    NodeTextField(label: "Reference Node Penalty", field: "ref"),
    NodeTextField(label: "Leaf Node Penalty", field: "leaf"),
    NodeTextField(label: "Non-leaf Node Penalty", field: "non_leaf"),
    NodeTextField(label: "Used Feature Penalty", field: "used_feat"),
    NodeTextField(label: "Unused Feature Penalty", field: "unused_feat")
  ];

  DecisionPenalties({this.node = 0.0, this.branch = 0.0, this.ref = 0.0, this.leaf = 0.0, this.nonLeaf = 0.0, this.usedFeat = 0.0, this.unusedFeat = 0.0});

  factory DecisionPenalties.fromJson(Map<String, dynamic> json) {
    final node = getField<double>(json, "node", 0.0, doubleFromJson);
    final branch = getField<double>(json, "branch", 0.0, doubleFromJson);
    final ref = getField<double>(json, "ref", 0.0, doubleFromJson);
    final leaf = getField<double>(json, "leaf", 0.0, doubleFromJson);
    final nonLeaf = getField<double>(json, "non_leaf", 0.0, doubleFromJson);
    final usedFeat = getField<double>(json, "used_feat", 0.0, doubleFromJson);
    final unusedFeat = getField<double>(json, "unused_feat", 0.0, doubleFromJson);

    return DecisionPenalties(
      node: node,
      branch: branch,
      ref: ref,
      leaf: leaf,
      nonLeaf: nonLeaf,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat
    );
  }

  @override
  void updateField(String field, String text) {
    final value = double.tryParse(text) ?? 0.0;

    switch (field) {
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
  String formatField(String field) {
    return switch (field) {
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
    return {
      "type": "decision",
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
