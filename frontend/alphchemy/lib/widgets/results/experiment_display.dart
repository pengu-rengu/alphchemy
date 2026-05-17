import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";

class ExperimentDisplay extends StatelessWidget {
  final Experiment experiment;

  const ExperimentDisplay({super.key, required this.experiment});

  @override
  Widget build(BuildContext context) {
    final tile = ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 10),
      initiallyExpanded: false,
      title: const LargeText("Experiment Configuration"),
      children: [ExperimentNodeView(nodeData: experiment)]
    );

    return PaddedCard(child: tile);
  }
}

class ExperimentNodeView extends StatelessWidget {
  final NodeData nodeData;

  const ExperimentNodeView({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BoldText(nodeData.nodeType.value),
        const SizedBox(height: 5),
        FieldsView(nodeData: nodeData),
        const SizedBox(height: 5),
        SlotsView(nodeData: nodeData)
      ]
    );
  }
}

class FieldsView extends StatelessWidget {
  final NodeData nodeData;

  const FieldsView({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: (() {
        final widgets = <Widget>[];

        for (final fieldWidget in nodeData.fields) {
          final entry = entryFor(fieldWidget);
          if (entry == null) {
            continue;
          }

          final value = nodeData.formatField(entry.field);
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: NormalText(entry.label)),
              Expanded(child: NormalText(value))
            ]
          );
          widgets.add(row);
        }

        return widgets;
      })(),
    );
  }

  ({String label, String field})? entryFor(Widget fieldWidget) {
    return switch (fieldWidget) {
      NodeTextField() => (label: fieldWidget.label, field: fieldWidget.field),
      NodeDropdown() => (label: fieldWidget.label, field: fieldWidget.field),
      NodeBoolDropdown() => (label: fieldWidget.label, field: fieldWidget.field),
      NodeDateTimeField() => (label: fieldWidget.label, field: fieldWidget.field),
      _ => null
    };
  }
}

class SlotsView extends StatelessWidget {
  final NodeData nodeData;

  const SlotsView({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: (() {
        final widgets = <Widget>[];

        for (final slot in nodeData.childSlots) {
          final slotChildren = nodeData.childrenInSlot(slot.field);
          final label = NormalText(slot.label + (slot.isMulti ?  "  (${slotChildren.length})" : ""));
          widgets.add(label);

          for (final child in slotChildren) {
            final childView = Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: ExperimentNodeView(nodeData: child)
            );
            widgets.add(childView);
          }
        }

        return widgets;
      })(),
    );
  }
}
