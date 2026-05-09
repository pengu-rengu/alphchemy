import "package:alphchemy/model/experiment/actions.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/network.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/experiment/optimizer.dart";
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
      Experiment() => const ExperimentFields(),
      BacktestSchema() => const BacktestSchemaFields(),
      Strategy() => const StrategyContent(),
      Network() => const NetworkContent(),
      Actions() => const ActionsContent(),
      Penalties() => const PenaltiesContent(),
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
      Sma() => const OhlcWindowFeatureContent(),
      Ema() => const EmaFeatureContent(),
      Macd() => const MacdFeatureContent(),
      Rsi() => const RsiFeatureContent(),
      BollingerBands() => const BollingerBandsFeatureContent(),
      Stochastic() => const StochasticFeatureContent(),
      Atr() => const AtrFeatureContent(),
      Roc() => const OhlcWindowFeatureContent(),
      DonchianChannel() => const DonchianChannelFeatureContent(),
      ThresholdRange() => const ThresholdRangeFields(),
      MetaAction() => const MetaActionFields(),
      LogicActions() => const LogicActionsFields(),
      DecisionActions() => const DecisionActionsContent(),
      EntrySchema() => const EntrySchemaFields(),
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
