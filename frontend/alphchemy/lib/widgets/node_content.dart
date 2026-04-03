import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/experiment.dart";
import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/optimizer.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class NodeFields extends StatelessWidget {
  final NodeObject nodeData;

  const NodeFields({
    super.key,
    required this.nodeData
  });

  @override
  Widget build(BuildContext context) {
    final Widget? fields = switch (nodeData) {
      ExperimentGenerator() => ExperimentGenContent(),
      BacktestSchema() => BacktestSchemaContent(),
      StrategyGen() => StrategyGenContent(),
      NetworkGen() => NetworkGenContent(),
      ActionsGen() => ActionsGenContent(),
      PenaltiesGen() => PenaltiesGenContent(),
      LogicNet() => LogicNetContent(),
      DecisionNet() => DecisionNetContent(),
      InputNode() => InputNodeContent(),
      GateNode() => GateNodeContent(),
      BranchNode() => BranchNodeContent(),
      RefNode() => RefNodeContent(),
      NodePtr() => NodePtrContent(),
      LogicPenalties() => LogicPenaltiesContent(),
      DecisionPenalties() => DecisionPenaltiesContent(),
      StopConds() => StopCondsContent(),
      GeneticOpt() => GeneticOptContent(),
      ConstantFeature() => ConstantFeatureContent(),
      RawReturnsFeature() => RawReturnsFeatureContent(),
      ThresholdRange() => ThresholdRangeContent(),
      MetaAction() => MetaActionContent(),
      LogicActions() => LogicActionsContent(),
      DecisionActions() => DecisionActionsContent(),
      EntrySchema() => EntrySchemaContent(),
      ExitSchema() => ExitSchemaContent(),
      _ => null
    };

    if (fields == null) {
      return SizedBox();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5),
        fields
      ]
    );
  }
}

class NodeContent extends StatelessWidget {
  final Node<NodeObject> node;

  const NodeContent({
    super.key,
    required this.node
  });

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
              padding: EdgeInsets.all(10),
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
                          fontWeight: FontWeight.bold
                        )
                      ),
                      NodeFields(nodeData: data)
                    ]
                  );
                }
              )
            )
          );
        }
      )
    );
  }
}
