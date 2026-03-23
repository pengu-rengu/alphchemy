import 'package:alphchemy/model/json_helpers.dart';

enum Anchor {
  fromStart,
  fromEnd;

  static Anchor fromJson(String json) {
    switch (json) {
      case 'from_start': return Anchor.fromStart;
      case 'from_end': return Anchor.fromEnd;
      default: throw ArgumentError('Invalid Anchor: $json');
    }
  }

  String toJson() {
    switch (this) {
      case Anchor.fromStart: return 'from_start';
      case Anchor.fromEnd: return 'from_end';
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

  static Gate fromJson(String json) {
    switch (json) {
      case 'and': return Gate.and;
      case 'or': return Gate.or;
      case 'xor': return Gate.xor;
      case 'nand': return Gate.nand;
      case 'nor': return Gate.nor;
      case 'xnor': return Gate.xnor;
      default: throw ArgumentError('Invalid Gate: $json');
    }
  }

  String toJson() {
    return name;
  }
}

Gate gateFromDynamic(dynamic val) {
  final str = val as String;
  return Gate.fromJson(str);
}

class NodePtr {
  final Anchor anchor;
  final int idx;

  NodePtr({
    required this.anchor,
    required this.idx
  });

  factory NodePtr.fromJson(Map<String, dynamic> json) {
    final anchorStr = json['anchor'] as String;
    final anchor = Anchor.fromJson(anchorStr);
    final idx = json['idx'] as int;
    return NodePtr(anchor: anchor, idx: idx);
  }

  Map<String, dynamic> toJson() {
    return {
      'anchor': anchor.toJson(),
      'idx': idx
    };
  }
}

sealed class LogicNode {
  const LogicNode();

  factory LogicNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'input': return InputNode.fromJson(json);
      case 'gate': return GateNode.fromJson(json);
      default: throw ArgumentError('Invalid LogicNode type: $type');
    }
  }

  Map<String, dynamic> toJson();
}

LogicNode logicNodeFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return LogicNode.fromJson(map);
}

class InputNode extends LogicNode {
  final double? threshold;
  final int? featIdx;

  InputNode({
    required this.threshold,
    required this.featIdx
  });

  factory InputNode.fromJson(Map<String, dynamic> json) {
    final threshold = nullDoubleFromJson(json['threshold']);
    final featIdx = json['feat_idx'] as int?;
    return InputNode(threshold: threshold, featIdx: featIdx);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'input',
      'threshold': threshold,
      'feat_idx': featIdx
    };
  }
}

class GateNode extends LogicNode {
  final Gate? gate;
  final int? in1Idx;
  final int? in2Idx;

  GateNode({
    required this.gate,
    required this.in1Idx,
    required this.in2Idx
  });

  factory GateNode.fromJson(Map<String, dynamic> json) {
    final gateStr = json['gate'] as String?;
    final gate = gateStr != null ? Gate.fromJson(gateStr) : null;
    final in1Idx = json['in1_idx'] as int?;
    final in2Idx = json['in2_idx'] as int?;
    return GateNode(gate: gate, in1Idx: in1Idx, in2Idx: in2Idx);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'gate',
      'gate': gate?.toJson(),
      'in1_idx': in1Idx,
      'in2_idx': in2Idx
    };
  }
}

class LogicNet {
  final List<LogicNode> nodes;
  final bool defaultValue;

  LogicNet({
    required this.nodes,
    required this.defaultValue
  });

  factory LogicNet.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List<dynamic>;
    final nodes = listFromJson(rawNodes, logicNodeFromDynamic);
    final defaultValue = json['default_value'] as bool;
    return LogicNet(nodes: nodes, defaultValue: defaultValue);
  }

  Map<String, dynamic> toJson() {
    final nodesList = listFromJson(nodes, (node) => node.toJson());
    return {
      'nodes': nodesList,
      'default_value': defaultValue
    };
  }
}

class LogicPenalties {
  final double node;
  final double input;
  final double gate;
  final double recurrence;
  final double feedforward;
  final double usedFeat;
  final double unusedFeat;

  LogicPenalties({
    required this.node,
    required this.input,
    required this.gate,
    required this.recurrence,
    required this.feedforward,
    required this.usedFeat,
    required this.unusedFeat
  });

  factory LogicPenalties.fromJson(Map<String, dynamic> json) {
    final node = doubleFromJson(json['node']);
    final input = doubleFromJson(json['input']);
    final gate = doubleFromJson(json['gate']);
    final recurrence = doubleFromJson(json['recurrence']);
    final feedforward = doubleFromJson(json['feedforward']);
    final usedFeat = doubleFromJson(json['used_feat']);
    final unusedFeat = doubleFromJson(json['unused_feat']);
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

  Map<String, dynamic> toJson() {
    return {
      'node': node,
      'input': input,
      'gate': gate,
      'recurrence': recurrence,
      'feedforward': feedforward,
      'used_feat': usedFeat,
      'unused_feat': unusedFeat
    };
  }
}

sealed class DecisionNode {
  const DecisionNode();

  factory DecisionNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'branch': return BranchNode.fromJson(json);
      case 'ref': return RefNode.fromJson(json);
      default: throw ArgumentError('Invalid DecisionNode type: $type');
    }
  }

  Map<String, dynamic> toJson();
}

DecisionNode decisionNodeFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return DecisionNode.fromJson(map);
}

class BranchNode extends DecisionNode {
  final double? threshold;
  final int? featIdx;
  final int? trueIdx;
  final int? falseIdx;

  BranchNode({
    required this.threshold,
    required this.featIdx,
    required this.trueIdx,
    required this.falseIdx
  });

  factory BranchNode.fromJson(Map<String, dynamic> json) {
    final threshold = nullDoubleFromJson(json['threshold']);
    final featIdx = json['feat_idx'] as int?;
    final trueIdx = json['true_idx'] as int?;
    final falseIdx = json['false_idx'] as int?;
    return BranchNode(
      threshold: threshold,
      featIdx: featIdx,
      trueIdx: trueIdx,
      falseIdx: falseIdx
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'branch',
      'threshold': threshold,
      'feat_idx': featIdx,
      'true_idx': trueIdx,
      'false_idx': falseIdx
    };
  }
}

class RefNode extends DecisionNode {
  final int? refIdx;
  final int? trueIdx;
  final int? falseIdx;

  RefNode({
    required this.refIdx,
    required this.trueIdx,
    required this.falseIdx
  });

  factory RefNode.fromJson(Map<String, dynamic> json) {
    final refIdx = json['ref_idx'] as int?;
    final trueIdx = json['true_idx'] as int?;
    final falseIdx = json['false_idx'] as int?;
    return RefNode(refIdx: refIdx, trueIdx: trueIdx, falseIdx: falseIdx);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'ref',
      'ref_idx': refIdx,
      'true_idx': trueIdx,
      'false_idx': falseIdx
    };
  }
}

class DecisionNet {
  final List<DecisionNode> nodes;
  final int maxTrailLen;
  final bool defaultValue;

  DecisionNet({
    required this.nodes,
    required this.maxTrailLen,
    required this.defaultValue
  });

  factory DecisionNet.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List<dynamic>;
    final nodes = listFromJson(rawNodes, decisionNodeFromDynamic);
    final maxTrailLen = json['max_trail_len'] as int;
    final defaultValue = json['default_value'] as bool;
    return DecisionNet(
      nodes: nodes,
      maxTrailLen: maxTrailLen,
      defaultValue: defaultValue
    );
  }

  Map<String, dynamic> toJson() {
    final nodesList = listFromJson(nodes, (node) => node.toJson());
    return {
      'nodes': nodesList,
      'max_trail_len': maxTrailLen,
      'default_value': defaultValue
    };
  }
}

class DecisionPenalties {
  final double node;
  final double branch;
  final double ref_;
  final double leaf;
  final double nonLeaf;
  final double usedFeat;
  final double unusedFeat;

  DecisionPenalties({
    required this.node,
    required this.branch,
    required this.ref_,
    required this.leaf,
    required this.nonLeaf,
    required this.usedFeat,
    required this.unusedFeat
  });

  factory DecisionPenalties.fromJson(Map<String, dynamic> json) {
    final node = doubleFromJson(json['node']);
    final branch = doubleFromJson(json['branch']);
    final ref_ = doubleFromJson(json['ref']);
    final leaf = doubleFromJson(json['leaf']);
    final nonLeaf = doubleFromJson(json['non_leaf']);
    final usedFeat = doubleFromJson(json['used_feat']);
    final unusedFeat = doubleFromJson(json['unused_feat']);
    return DecisionPenalties(
      node: node,
      branch: branch,
      ref_: ref_,
      leaf: leaf,
      nonLeaf: nonLeaf,
      usedFeat: usedFeat,
      unusedFeat: unusedFeat
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node': node,
      'branch': branch,
      'ref': ref_,
      'leaf': leaf,
      'non_leaf': nonLeaf,
      'used_feat': usedFeat,
      'unused_feat': unusedFeat
    };
  }
}
