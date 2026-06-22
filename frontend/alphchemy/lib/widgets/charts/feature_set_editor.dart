/*
import "package:alphchemy/blocs/feature_sets/feature_set_bloc.dart";
import "package:alphchemy/blocs/experiments/node_data_bloc.dart";
import "package:alphchemy/model/feature_set/feature_set.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class FeatureSetEditor extends StatelessWidget {
  const FeatureSetEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
      children: [
        // ignore: prefer_const_constructors
        FeatureSetTimestamps(),
        const Divider(height: 1),
        Expanded(child: FeatureSetFeatList(
          key: ValueKey<int>(state.featureSet.id)
        )),
        const Divider(height: 1),
        const FeatureSetEditorFooter()
      ]
    );
  }
}

class FeatureSetTimestamps extends StatelessWidget {
  const FeatureSetTimestamps({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    final featureSet = state.featureSet;
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateTimeFieldInput(
            label: "Start Timestamp",
            labelOnLeft: false,
            timestamp: featureSet.startTimestamp,
            onChanged: (value) {
              final event = UpdateStartTimestamp(value: value);
              context.read<FeatureSetBloc>().add(event);
            }
          ),
          const SizedBox(height: 5.0),
          DateTimeFieldInput(
            label: "End Timestamp",
            labelOnLeft: false,
            timestamp: featureSet.endTimestamp,
            onChanged: (value) {
              final event = UpdateEndTimestamp(value: value);
              context.read<FeatureSetBloc>().add(event);
            }
          )
        ]
      )
    );
  }
}

class FeatureSetFeatList extends StatelessWidget {
  const FeatureSetFeatList({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    final feats = state.featureSet.feats;

    return feats.isEmpty ? const CenterText("No features yet") : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      itemCount: feats.length,
      itemBuilder: (_, idx) {
        final feat = feats[idx];
        return Padding(
          padding: EdgeInsets.only(top: idx == 0 ? 5.0 : 0.0, bottom: 5.0),
          child: FeatCard(
            key: ValueKey<String>(feat.nodeId),
            feat: feat
          )
        );
      }
    );
  }
}

class FeatCard extends StatelessWidget {
  final NodeData feat;

  const FeatCard({super.key, required this.feat});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NodeDataBloc>(
      create: (_) => NodeDataBloc(nodeData: feat),
      child: _FeatCardBody(feat: feat)
    );
  }
}

class _FeatCardBody extends StatelessWidget {
  final NodeData feat;

  const _FeatCardBody({required this.feat});

  @override
  Widget build(BuildContext context) {
    return BlocListener<NodeDataBloc, NodeData>(
      listener: (context, state) {
        final event = UpdateFeature(nodeId: feat.nodeId, feature: state);
        context.read<FeatureSetBloc>().add(event);
      },
      child: PaddedCard(child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        initiallyExpanded: true,
        title: NormalText(feat.nodeType.value),
        trailing: IconButton(
          icon: const NormalIcon(Icons.delete_outline),
          tooltip: "Remove",
          onPressed: () {
            final event = DeleteFeature(nodeId: feat.nodeId);
            context.read<FeatureSetBloc>().add(event);
          }
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: NodeFields(nodeData: feat)
          )
        ]
      ))
    );
  }
}

class FeatureSetEditorFooter extends StatelessWidget {
  const FeatureSetEditorFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(10.0),
      child: Row(children: [
        Spacer(),
        AddFeatButton()
      ])
    );
  }
}

class AddFeatButton extends StatelessWidget {
  const AddFeatButton({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) => FilledButton.icon(
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const InvertedIcon(Icons.add),
        label: const InvertedText("Add feature")
      ),
      menuChildren: featureNodeTypes.map((nodeType) {
        return MenuItemButton(
          onPressed: () {
            final event = AddFeature(nodeType: nodeType);
            context.read<FeatureSetBloc>().add(event);
          },
          child: NormalText(nodeType.value)
        );
      }).toList()
    );
  }
}
*/
