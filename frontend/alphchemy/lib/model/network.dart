import 'package:alphchemy/model/node_object.dart';

enum Anchor {
  fromStart, fromEnd;

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
  and, or, xor, nand, nor, xnor;

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

class NodePtr extends NodeObject {
  Anchor anchor;
  int idx;

  @override
  String get nodeType => 'node_ptr';

  NodePtr({
    required this.anchor,
    required this.idx
  });
}

class InputNode extends NodeObject {
  double? threshold;
  int? featIdx;

  @override
  String get nodeType => 'input_node';

  InputNode({
    required this.threshold,
    required this.featIdx
  });
}

class GateNode extends NodeObject {
  Gate? gate;
  int? in1Idx;
  int? in2Idx;

  @override
  String get nodeType => 'gate_node';

  GateNode({
    required this.gate,
    required this.in1Idx,
    required this.in2Idx
  });
}

class LogicNet extends NodeObject {
  List<String> nodeIds;
  bool defaultValue;

  @override
  String get nodeType => 'logic_net';

  LogicNet({
    required this.nodeIds,
    required this.defaultValue
  });
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
  String get nodeType => 'logic_penalties';

  LogicPenalties({
    required this.node,
    required this.input,
    required this.gate,
    required this.recurrence,
    required this.feedforward,
    required this.usedFeat,
    required this.unusedFeat
  });
}

class BranchNode extends NodeObject {
  double? threshold;
  int? featIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => 'branch_node';

  BranchNode({
    required this.threshold,
    required this.featIdx,
    required this.trueIdx,
    required this.falseIdx
  });
}

class RefNode extends NodeObject {
  int? refIdx;
  int? trueIdx;
  int? falseIdx;

  @override
  String get nodeType => 'ref_node';

  RefNode({
    required this.refIdx,
    required this.trueIdx,
    required this.falseIdx
  });
}

class DecisionNet extends NodeObject {
  List<String> nodeIds;
  int maxTrailLen;
  bool defaultValue;

  @override
  String get nodeType => 'decision_net';

  DecisionNet({
    required this.nodeIds,
    required this.maxTrailLen,
    required this.defaultValue
  });
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
  String get nodeType => 'decision_penalties';

  DecisionPenalties({
    required this.node,
    required this.branch,
    required this.ref,
    required this.leaf,
    required this.nonLeaf,
    required this.usedFeat,
    required this.unusedFeat
  });
}
