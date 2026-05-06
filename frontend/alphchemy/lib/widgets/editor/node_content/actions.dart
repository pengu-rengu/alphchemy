import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class ThresholdRangeContent extends StatelessWidget {
  const ThresholdRangeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "id", fieldKey: "id"),
        _fieldGap,
        NodeTextField(label: "featId", fieldKey: "feat_id"),
        _fieldGap,
        NodeTextField(label: "min", fieldKey: "min"),
        _fieldGap,
        NodeTextField(label: "max", fieldKey: "max")
      ]
    );
  }
}

class MetaActionContent extends StatelessWidget {
  const MetaActionContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "id", fieldKey: "id"),
        _fieldGap,
        NodeTextField(label: "label", fieldKey: "label"),
        _fieldGap,
        NodeTextField(label: "subActs", fieldKey: "sub_actions")
      ]
    );
  }
}

class LogicActionsContent extends StatelessWidget {
  const LogicActionsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "featOrd", fieldKey: "feat_order"),
        _fieldGap,
        NodeTextField(label: "nThresh", fieldKey: "n_thresholds"),
        _fieldGap,
        NodeCheckbox(label: "recurrence", fieldKey: "allow_recurrence"),
        _fieldGap,
        NodeTextField(label: "gates", fieldKey: "allowed_gates")
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
        NodeTextField(label: "featOrd", fieldKey: "feat_order"),
        _fieldGap,
        NodeTextField(label: "nThresh", fieldKey: "n_thresholds"),
        _fieldGap,
        NodeCheckbox(label: "allowRefs", fieldKey: "allow_refs")
      ]
    );
  }
}
