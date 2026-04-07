import "package:alphchemy/model/generator/network.dart";
import "package:alphchemy/model/generator/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);
const _generatorTypes = ["logic", "decision"];

class NodePtrContent extends StatelessWidget {
  const NodePtrContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeDropdown<Anchor>(
          label: "anchor",
          fieldKey: "anchor",
          paramType: ParamType.stringType,
          options: Anchor.values,
          labelFor: (val) => val.name,
        ),
        _fieldGap,
        const NodeTextField(
          label: "idx",
          fieldKey: "idx",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}

class InputNodeContent extends StatelessWidget {
  const InputNodeContent({super.key});

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
          label: "threshold",
          fieldKey: "threshold",
          paramType: ParamType.floatType,
        ),
      ],
    );
  }
}

class GateNodeContent extends StatelessWidget {
  const GateNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NodeTextField(
          label: "id",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeDropdown<Gate>(
          label: "gate",
          fieldKey: "gate",
          paramType: ParamType.stringType,
          options: Gate.values,
          labelFor: (val) => val.name,
        ),
        _fieldGap,
        const NodeTextField(
          label: "in1Idx",
          fieldKey: "in1_idx",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        const NodeTextField(
          label: "in2Idx",
          fieldKey: "in2_idx",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}

class BranchNodeContent extends StatelessWidget {
  const BranchNodeContent({super.key});

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
          label: "threshold",
          fieldKey: "threshold",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "trueIdx",
          fieldKey: "true_idx",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "falseIdx",
          fieldKey: "false_idx",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}

class RefNodeContent extends StatelessWidget {
  const RefNodeContent({super.key});

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
          label: "refIdx",
          fieldKey: "ref_idx",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "trueIdx",
          fieldKey: "true_idx",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "falseIdx",
          fieldKey: "false_idx",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}

class LogicNetContent extends StatelessWidget {
  const LogicNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "nodeSel",
          fieldKey: "node_selection",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeCheckbox(
          label: "default",
          fieldKey: "default_value",
          paramType: ParamType.boolType,
        ),
      ],
    );
  }
}

class DecisionNetContent extends StatelessWidget {
  const DecisionNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "nodeSel",
          fieldKey: "node_selection",
          paramType: ParamType.stringListType,
        ),
        _fieldGap,
        NodeTextField(
          label: "maxTrail",
          fieldKey: "max_trail_len",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeCheckbox(
          label: "default",
          fieldKey: "default_value",
          paramType: ParamType.boolType,
        ),
      ],
    );
  }
}

class NetworkGenContent extends StatelessWidget {
  const NetworkGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      fieldKey: "type",
      paramType: ParamType.stringType,
      options: _generatorTypes,
      labelFor: (val) => val,
    );
  }
}

class LogicPenaltiesContent extends StatelessWidget {
  const LogicPenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "node",
          fieldKey: "node",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "input",
          fieldKey: "input",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "gate",
          fieldKey: "gate",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "recurrence",
          fieldKey: "recurrence",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "feedfwd",
          fieldKey: "feedforward",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "usedFeat",
          fieldKey: "used_feat",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "unusedFeat",
          fieldKey: "unused_feat",
          paramType: ParamType.floatType,
        ),
      ],
    );
  }
}

class DecisionPenaltiesContent extends StatelessWidget {
  const DecisionPenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "node",
          fieldKey: "node",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "branch",
          fieldKey: "branch",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "ref",
          fieldKey: "ref",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "leaf",
          fieldKey: "leaf",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "nonLeaf",
          fieldKey: "non_leaf",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "usedFeat",
          fieldKey: "used_feat",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "unusedFeat",
          fieldKey: "unused_feat",
          paramType: ParamType.floatType,
        ),
      ],
    );
  }
}

class PenaltiesGenContent extends StatelessWidget {
  const PenaltiesGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      fieldKey: "type",
      paramType: ParamType.stringType,
      options: _generatorTypes,
      labelFor: (val) => val,
    );
  }
}
