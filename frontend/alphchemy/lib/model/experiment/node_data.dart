import "package:uuid/uuid.dart";

const _uuid = Uuid();

enum NodeType {
  constantFeature("constant_feature"),
  rawReturnsFeature("raw_returns_feature"),
  smaFeature("sma_feature"),
  emaFeature("ema_feature"),
  macdFeature("macd_feature"),
  rsiFeature("rsi_feature"),
  bollingerBandsFeature("bollinger_bands_feature"),
  stochasticFeature("stochastic_feature"),
  atrFeature("atr_feature"),
  rocFeature("roc_feature"),
  donchianChannelFeature("donchian_channel_feature"),
  experiment("experiment"),
  backtestSchema("backtest_schema"),
  strategy("strategy"),
  network("network"),
  logicNet("logic_net"),
  decisionNet("decision_net"),
  inputNode("input_node"),
  gateNode("gate_node"),
  branchNode("branch_node"),
  refNode("ref_node"),
  nodePtr("node_ptr"),
  actions("actions"),
  logicActions("logic_actions"),
  decisionActions("decision_actions"),
  metaAction("meta_action"),
  thresholdRange("threshold_range"),
  penalties("penalties"),
  logicPenalties("logic_penalties"),
  decisionPenalties("decision_penalties"),
  stopConds("stop_conds"),
  geneticOpt("genetic_opt"),
  entrySchema("entry_schema"),
  exitSchema("exit_schema");

  final String value;

  const NodeType(this.value);
}

class ChildSlot {
  final String key;
  final String label;
  final bool multi;
  final List<NodeType> allowedTypes;

  const ChildSlot({
    required this.key,
    required this.label,
    required this.multi,
    required this.allowedTypes
  });
}

class ChildOption {
  final ChildSlot slot;
  final NodeType nodeType;

  const ChildOption({required this.slot, required this.nodeType});
}

abstract class NodeData {
  final String nodeId;
  NodeType get nodeType;
  List<ChildSlot> get childSlots => const [];
  int get fieldCount => 0;

  NodeData() : nodeId = _uuid.v4();

  void updateField(String fieldKey, String text) {}

  void updateFieldTyped(String fieldKey, dynamic value) {}

  String formatField(String fieldKey);
  Map<String, dynamic> toJson();

  List<NodeData> get children {
    final result = <NodeData>[];

    for (final slot in childSlots) {
      final slotChildren = childrenInSlot(slot.key);
      result.addAll(slotChildren);
    }

    return result;
  }

  List<NodeData> childrenInSlot(String slotKey) {
    return const [];
  }

  List<ChildOption> childOptions(ChildSlot slot) {
    final existingChildren = childrenInSlot(slot.key);
    if (!slot.multi) {
      if (existingChildren.isNotEmpty) return const [];
    }

    final options = <ChildOption>[];
    for (final nodeType in slot.allowedTypes) {
      final option = ChildOption(slot: slot, nodeType: nodeType);
      options.add(option);
    }

    return options;
  }

  bool addChild(String slotKey, NodeData child) {
    final slot = findChildSlot(slotKey);
    if (slot == null) return false;
    if (!slot.allowedTypes.contains(child.nodeType)) return false;

    if (!slot.multi) {
      final existingChildren = childrenInSlot(slotKey);
      if (existingChildren.isNotEmpty) return false;
    }

    return attachChild(slotKey, child);
  }

  NodeData? find(String targetId) {
    if (nodeId == targetId) return this;

    for (final child in children) {
      final found = child.find(targetId);
      if (found != null) return found;
    }

    return null;
  }

  void visitChildren(void Function(NodeData object) visit) {
    visit(this);

    for (final child in children) {
      child.visitChildren(visit);
    }
  }

  bool removeChild(String targetId) {
    if (nodeId == targetId) return false;
    if (removeDirectChild(targetId)) return true;

    for (final child in children) {
      final removed = child.removeChild(targetId);
      if (removed) return true;
    }

    return false;
  }

  ChildSlot? findChildSlot(String slotKey) {
    for (final slot in childSlots) {
      if (slot.key == slotKey) return slot;
    }

    return null;
  }

  bool attachChild(String slotKey, NodeData child) {
    return false;
  }

  bool removeDirectChild(String targetId) {
    return false;
  }

  bool removeChildFromList<T extends NodeData>(List<T> objects, String targetId) {
    for (var i = 0; i < objects.length; i++) {
      final object = objects[i];
      if (object.nodeId != targetId) continue;
      objects.removeAt(i);
      return true;
    }

    return false;
  }

  List<String> parseList(String text) {
    final result = <String>[];

    for (final part in text.split(",")) {
      final trimmed = part.trim();

      if (trimmed.isNotEmpty) {
        result.add(trimmed);
      }
    }
    return result;
  }
}
