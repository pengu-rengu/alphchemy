import "package:alphchemy/model/generator/actions.dart";
import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator/features.dart";
import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/model/generator/optimizer.dart";
import "package:alphchemy/widgets/editor/node_content/actions.dart";
import "package:alphchemy/widgets/editor/node_content/experiment.dart";
import "package:alphchemy/widgets/editor/node_content/features.dart";
import "package:alphchemy/widgets/editor/node_content/network.dart";
import "package:alphchemy/widgets/editor/node_content/optimizer.dart";
import "package:flutter/material.dart" hide Actions;

class NodeFields extends StatelessWidget {
  final NodeData nodeData;

  const NodeFields({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    final Widget? fields = switch (nodeData) {
      ExperimentGenerator() => const ExperimentGenContent(),
      BacktestSchema() => const BacktestSchemaContent(),
      Strategy() => const StrategyGenContent(),
      Network() => const NetworkGenContent(),
      Actions() => const ActionsGenContent(),
      Penalties() => const PenaltiesGenContent(),
      LogicNet() => const LogicNetContent(),
      DecisionNet() => const DecisionNetContent(),
      InputNode() => const InputNodeContent(),
      GateNode() => const GateNodeContent(),
      BranchNode() => const BranchNodeContent(),
      RefNode() => const RefNodeContent(),
      NodePtr() => const NodePtrContent(),
      LogicPenalties() => const LogicPenaltiesContent(),
      DecisionPenalties() => const DecisionPenaltiesContent(),
      StopConds() => const StopCondsContent(),
      GeneticOpt() => const GeneticOptContent(),
      Constant() => const ConstantFeatureContent(),
      RawReturns() => const RawReturnsFeatureContent(),
      ThresholdRange() => const ThresholdRangeContent(),
      MetaAction() => const MetaActionContent(),
      LogicActions() => const LogicActionsContent(),
      DecisionActions() => const DecisionActionsContent(),
      EntrySchema() => const EntrySchemaContent(),
      ExitSchema() => const ExitSchemaContent(),
      _ => null
    };

    if (fields == null) {
      return const SizedBox();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SizedBox(height: 5), fields]
    );
  }
}
