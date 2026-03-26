import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

Widget nodeContentFor(Node<NodeObject> node) {
  final data = node.data;
  final fields = switch (data) {
    ExperimentGenerator() => ExperimentGenContent(data: data),
    BacktestSchema() => BacktestSchemaContent(data: data),
    StrategyGen() => StrategyGenContent(data: data),
    Strategy() => StrategyContent(data: data),
    Experiment() => ExperimentContent(data: data),
    NetworkGen() => NetworkGenContent(data: data),
    ActionsGen() => ActionsGenContent(data: data),
    PenaltiesGen() => PenaltiesGenContent(data: data),
    LogicNet() => LogicNetContent(data: data),
    DecisionNet() => DecisionNetContent(data: data),
    InputNode() => InputNodeContent(data: data),
    GateNode() => GateNodeContent(data: data),
    BranchNode() => BranchNodeContent(data: data),
    RefNode() => RefNodeContent(data: data),
    NodePtr() => NodePtrContent(data: data),
    LogicPenalties() => LogicPenaltiesContent(data: data),
    DecisionPenalties() => DecisionPenaltiesContent(data: data),
    StopConds() => StopCondsContent(data: data),
    GeneticOpt() => GeneticOptContent(data: data),
    ConstantFeature() => ConstantFeatureContent(data: data),
    RawReturnsFeature() => RawReturnsFeatureContent(data: data),
    ThresholdRange() => ThresholdRangeContent(data: data),
    MetaAction() => MetaActionContent(data: data),
    LogicActions() => LogicActionsContent(data: data),
    DecisionActions() => DecisionActionsContent(data: data),
    EntrySchema() => EntrySchemaContent(data: data),
    ExitSchema() => ExitSchemaContent(data: data),
    _ => null
  };
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        data.nodeType,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white
        )
      ),
      if (fields != null) ...[
        SizedBox(height: 4),
        fields
      ]
    ]
  );
}
