import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class ThresholdRangeContent extends StatelessWidget {
  const ThresholdRangeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "thresholdId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "id", fieldKey: "thresholdId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "featId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "featId", fieldKey: "featId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "min",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "min", fieldKey: "min"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "max",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "max", fieldKey: "max"),
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
        ParamField(
          fieldKey: "metaActionId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "id", fieldKey: "metaActionId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "label",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "label", fieldKey: "label"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "subActions",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "subActs", fieldKey: "subActions"),
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
        ParamField(
          fieldKey: "metaActionSelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(
            label: "metaSel",
            fieldKey: "metaActionSelection",
          ),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "thresholdSelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(
            label: "threshSel",
            fieldKey: "thresholdSelection",
          ),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "featOrder",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "featOrd", fieldKey: "featOrder"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "nThresholds",
          paramType: ParamType.intType,
          child: NodeTextField(label: "nThresh", fieldKey: "nThresholds"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "allowRecurrence",
          paramType: ParamType.boolType,
          child: NodeCheckbox(label: "recurrence", fieldKey: "allowRecurrence"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "allowedGates",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "gates", fieldKey: "allowedGates"),
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
        ParamField(
          fieldKey: "metaActionSelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(
            label: "metaSel",
            fieldKey: "metaActionSelection",
          ),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "thresholdSelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(
            label: "threshSel",
            fieldKey: "thresholdSelection",
          ),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "featOrder",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "featOrd", fieldKey: "featOrder"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "nThresholds",
          paramType: ParamType.intType,
          child: NodeTextField(label: "nThresh", fieldKey: "nThresholds"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "allowRefs",
          paramType: ParamType.boolType,
          child: NodeCheckbox(label: "allowRefs", fieldKey: "allowRefs"),
        ),
      ],
    );
  }
}
