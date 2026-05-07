import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

class ThresholdRangeFields extends StatelessWidget {
  const ThresholdRangeFields({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "id", fieldKey: "id"),
        SizedBox(height: 2),
        NodeTextField(label: "feature id", fieldKey: "feat_id"),
        SizedBox(height: 2),
        NodeTextField(label: "min", fieldKey: "min"),
        SizedBox(height: 2),
        NodeTextField(label: "max", fieldKey: "max")
      ]
    );
  }
}

class MetaActionFields extends StatelessWidget {
  const MetaActionFields({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "id", fieldKey: "id"),
        SizedBox(height: 2),
        NodeTextField(label: "label", fieldKey: "label"),
        SizedBox(height: 2),
        NodeTextField(label: "sub actions", fieldKey: "sub_actions")
      ]
    );
  }
}

class LogicActionsFields extends StatelessWidget {
  const LogicActionsFields({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "feature order", fieldKey: "feat_order"),
        SizedBox(height: 2),
        NodeTextField(label: "n thresholds", fieldKey: "n_thresholds"),
        SizedBox(height: 2),
        NodeCheckbox(label: "allow recurrence", fieldKey: "allow_recurrence"),
        SizedBox(height: 2),
        NodeTextField(label: "allowed gates", fieldKey: "allowed_gates")
      ]
    );
  }
}

class DecisionActionsContent extends StatelessWidget {
  const DecisionActionsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "feature order", fieldKey: "feat_order"),
        SizedBox(height: 2),
        NodeTextField(label: "n thresholds", fieldKey: "n_thresholds"),
        SizedBox(height: 2),
        NodeCheckbox(label: "allow references", fieldKey: "allow_refs")
      ]
    );
  }
}
