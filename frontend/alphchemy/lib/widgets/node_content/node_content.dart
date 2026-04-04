import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:alphchemy/widgets/node_content/actions.dart";
import "package:alphchemy/widgets/node_content/experiment.dart";
import "package:alphchemy/widgets/node_content/features.dart";
import "package:alphchemy/widgets/node_content/network.dart";
import "package:alphchemy/widgets/node_content/optimizer.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class NodeFields extends StatelessWidget {
  final NodeObject nodeData;

  const NodeFields({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    final Widget? fields = switch (nodeData) {
      ExperimentGenerator() => const ExperimentGenContent(),
      BacktestSchema() => const BacktestSchemaContent(),
      StrategyGen() => const StrategyGenContent(),
      NetworkGen() => const NetworkGenContent(),
      ActionsGen() => const ActionsGenContent(),
      PenaltiesGen() => const PenaltiesGenContent(),
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
      ConstantFeature() => const ConstantFeatureContent(),
      RawReturnsFeature() => const RawReturnsFeatureContent(),
      ThresholdRange() => const ThresholdRangeContent(),
      MetaAction() => const MetaActionContent(),
      LogicActions() => const LogicActionsContent(),
      DecisionActions() => const DecisionActionsContent(),
      EntrySchema() => const EntrySchemaContent(),
      ExitSchema() => const ExitSchemaContent(),
      _ => null,
    };

    if (fields == null) {
      return const SizedBox();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const SizedBox(height: 5), fields],
    );
  }
}

class NodeContent extends StatelessWidget {
  final Node<NodeObject> node;

  const NodeContent({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = NodeDataBloc(node: node);
        bloc.add(const NodeDataResize());
        return bloc;
      },
      child: Builder(
        builder: (context) {
          final bloc = context.read<NodeDataBloc>();
          return OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Padding(
              key: bloc.contentKey,
              padding: const EdgeInsets.all(10),
              child: BlocBuilder<NodeDataBloc, NodeDataState>(
                builder: (context, state) {
                  final data = node.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.nodeType,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      NodeFields(nodeData: data),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
