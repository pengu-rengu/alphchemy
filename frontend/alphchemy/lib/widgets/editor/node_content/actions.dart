import "package:alphchemy/model/generator/param_space.dart";
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
        NodeTextField(
          label: "id",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeTextField(
          label: "featId",
          fieldKey: "feat_id",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeTextField(
          label: "min",
          fieldKey: "min",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "max",
          fieldKey: "max",
          paramType: ParamType.floatType,
        ),
      ],
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
        NodeTextField(
          label: "id",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeTextField(
          label: "label",
          fieldKey: "label",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeTextField(
          label: "subActs",
          fieldKey: "sub_actions",
          paramType: ParamType.stringListType,
        ),
      ],
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
        NodeTextField(
          label: "metaSel",
          fieldKey: "meta_action_selection",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "threshSel",
          fieldKey: "threshold_selection",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "featOrd",
          fieldKey: "feat_order",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "nThresh",
          fieldKey: "n_thresholds",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeCheckbox(
          label: "recurrence",
          fieldKey: "allow_recurrence",
          paramType: ParamType.boolType,
        ),
        _fieldGap,
        NodeTextField(
          label: "gates",
          fieldKey: "allowed_gates",
          paramType: ParamType.stringListType,
        ),
      ],
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
        NodeTextField(
          label: "metaSel",
          fieldKey: "meta_action_selection",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "threshSel",
          fieldKey: "threshold_selection",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "featOrd",
          fieldKey: "feat_order",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "nThresh",
          fieldKey: "n_thresholds",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeCheckbox(
          label: "allowRefs",
          fieldKey: "allow_refs",
          paramType: ParamType.boolType,
        ),
      ],
    );
  }
}
