import "package:alphchemy/blocs/feature_set_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/main.dart";
import "package:alphchemy/model/feature_set/feature_set.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:alphchemy/widgets/widget_utils.dart";
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

class RequestValuesButton extends StatelessWidget {
  const RequestValuesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    final working = state.featureSet.status == FeatureSetStatus.working;

    return FilledButton.icon(
      onPressed: working ? null : () {
        context.read<FeatureSetBloc>().add(const RequestValues());
      },
      icon: InvertedIcon(working ? Icons.hourglass_top : Icons.send),
      label: InvertedText(working ? "Working..." : "Request Values")
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
            timestamp: featureSet.startTimestamp,
            onChanged: (value) {
              final event = UpdateStartTimestamp(value: value);
              context.read<FeatureSetBloc>().add(event);
            }
          ),
          const SizedBox(height: 6),
          DateTimeFieldInput(
            label: "End Timestamp",
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

    if (feats.isEmpty) {
      return const Center(child: NormalText("No features yet"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: feats.length,
      itemBuilder: (context, index) {
        final feat = feats[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: dark3),
          color: dark2
        ),
        child: ExpansionTile(
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
        )
      )
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
        Expanded(child: SizedBox()),
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
