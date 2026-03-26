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
      ExperimentGenerator data => ExperimentGenContent(data: data),
      BacktestSchema data => BacktestSchemaContent(data: data),
      StrategyGen data => StrategyGenContent(data: data),
      Strategy data => StrategyContent(data: data),
      Experiment data => ExperimentContent(data: data),
      NetworkGen data => NetworkGenContent(data: data),
      ActionsGen data => ActionsGenContent(data: data),
      PenaltiesGen data => PenaltiesGenContent(data: data),
      LogicNet data => LogicNetContent(data: data),
      DecisionNet data => DecisionNetContent(data: data),
      InputNode data => InputNodeContent(data: data),
      GateNode data => GateNodeContent(data: data),
      BranchNode data => BranchNodeContent(data: data),
      RefNode data => RefNodeContent(data: data),
      NodePtr data => NodePtrContent(data: data),
      LogicPenalties data => LogicPenaltiesContent(data: data),
      DecisionPenalties data => DecisionPenaltiesContent(data: data),
      StopConds data => StopCondsContent(data: data),
      GeneticOpt data => GeneticOptContent(data: data),
      ConstantFeature data => ConstantFeatureContent(data: data),
      RawReturnsFeature data => RawReturnsFeatureContent(data: data),
      ThresholdRange data => ThresholdRangeContent(data: data),
      MetaAction data => MetaActionContent(data: data),
      LogicActions data => LogicActionsContent(data: data),
      DecisionActions data => DecisionActionsContent(data: data),
      EntrySchema data => EntrySchemaContent(data: data),
      ExitSchema data => ExitSchemaContent(data: data),
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
