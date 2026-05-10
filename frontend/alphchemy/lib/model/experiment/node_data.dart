import "package:alphchemy/model/experiment/actions.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/network.dart";
import "package:alphchemy/model/experiment/optimizer.dart";
import "package:flutter/widgets.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

enum NodeType {
  constant("Constant"),
  rawReturns("Raw Returns"),
  normalizedSma("Normalized Simple Moving Average"),
  normalizedEma("Normalized Exponential Moving Average"),
  normalizedMacd("Normalized Moving Average Convergence Divergence"),
  rsi("Relative Strength Index"),
  normalizedBb("Normalized Bollinger Bands"),
  stochastic("Stochastic Oscillator"),
  atr("Normalized Average True Range"),
  roc("Rate of Change"),
  normalizedDc("Normalized Donchian Channels"),
  experiment("Experiment"),
  backtestSchema("Backtest Schema"),
  strategy("Strategy"),
  logicNet("Logic Network"),
  decisionNet("Decision Network"),
  inputNode("Input Node"),
  gateNode("Gate Node"),
  branchNode("Branch Node"),
  refNode("Reference Node"),
  nodePtr("Node Pointer"),
  logicActions("Logic Actions"),
  decisionActions("Decision Actions"),
  metaAction("Meta Action"),
  thresholdRange("Threshold Range"),
  logicPenalties("Logic Penalties"),
  decisionPenalties("Decision Penalties"),
  stopConds("Stop Conditions"),
  geneticOpt("Genetic Optimizer"),
  entrySchema("Entry Schema"),
  exitSchema("Exit Schema");

  final String value;

  const NodeType(this.value);

  NodeData emptyNode() {
    return switch (this) {
      NodeType.experiment => Experiment(),
      NodeType.backtestSchema => BacktestSchema(),
      NodeType.strategy => Strategy(),
      NodeType.logicNet => LogicNet(),
      NodeType.decisionNet => DecisionNet(),
      NodeType.inputNode => InputNode(),
      NodeType.gateNode => GateNode(),
      NodeType.branchNode => BranchNode(),
      NodeType.refNode => RefNode(),
      NodeType.nodePtr => NodePtr(),
      NodeType.constant => Constant(),
      NodeType.rawReturns => RawReturns(),
      NodeType.normalizedSma => NormalizedSMA(),
      NodeType.normalizedEma => NormalizedEMA(),
      NodeType.normalizedMacd => NormalizedMACD(),
      NodeType.rsi => RSI(),
      NodeType.normalizedBb => NormalizedBB(),
      NodeType.stochastic => Stochastic(),
      NodeType.atr => NormalizedATR(),
      NodeType.roc => ROC(),
      NodeType.normalizedDc => NormalizedDC(),
      NodeType.logicActions => LogicActions(),
      NodeType.decisionActions => DecisionActions(),
      NodeType.metaAction => MetaAction(),
      NodeType.thresholdRange => ThresholdRange(),
      NodeType.logicPenalties => LogicPenalties(),
      NodeType.decisionPenalties => DecisionPenalties(),
      NodeType.stopConds => StopConds(),
      NodeType.geneticOpt => GeneticOpt(),
      NodeType.entrySchema => EntrySchema(),
      NodeType.exitSchema => ExitSchema()
    };
  }
}

class ChildSlot {
  final String field;
  final String label;
  final bool isMulti;
  final List<NodeType> allowedTypes;

  const ChildSlot({required this.field, required this.label, required this.isMulti, required this.allowedTypes});
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
  List<Widget> get fields => const [];

  NodeData() : nodeId = _uuid.v4();

  void updateField(String field, String text) {}

  void updateFieldTyped(String field, dynamic value) {}

  String formatField(String field);
  Map<String, dynamic> toJson();

  List<NodeData> get children {
    final result = <NodeData>[];

    for (final slot in childSlots) {
      final slotChildren = childrenInSlot(slot.field);
      result.addAll(slotChildren);
    }

    return result;
  }

  List<NodeData> childrenInSlot(String field) {
    return const [];
  }

  List<ChildOption> childOptions(ChildSlot slot) {
    final existingChildren = childrenInSlot(slot.field);
    if (!slot.isMulti && existingChildren.isNotEmpty) {
      return const [];
    }

    toOption(NodeType nodeType) => ChildOption(slot: slot, nodeType: nodeType);    
    return slot.allowedTypes.map(toOption).toList();
  }

  bool addChild(String field, NodeData child) {
    for (final slot in childSlots) {
      if (slot.field == field) {
        if (!slot.allowedTypes.contains(child.nodeType)) {
          return false;
        }

        if (!slot.isMulti) {
          final existingChildren = childrenInSlot(field);
          if (existingChildren.isNotEmpty) {
            return false;
          }
        }

        return attachChild(field, child);
      }
    }

    return false;
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

  bool attachChild(String field, NodeData child) {
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
