import "package:alphchemy/model/experiment/network.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);
const networkTypes = ["logic", "decision"];

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
          options: Anchor.values,
          optionLabel: (val) => val.name
        ),
        _fieldGap,
        const NodeTextField(label: "idx", fieldKey: "idx")
      ]
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
        NodeTextField(label: "id", fieldKey: "id"),
        _fieldGap,
        NodeTextField(label: "featId", fieldKey: "feat_id"),
        _fieldGap,
        NodeTextField(label: "threshold", fieldKey: "threshold")
      ]
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
        const NodeTextField(label: "id", fieldKey: "id"),
        _fieldGap,
        NodeDropdown<Gate>(
          label: "gate",
          fieldKey: "gate",
          options: Gate.values,
          optionLabel: (val) => val.name
        ),
        _fieldGap,
        const NodeTextField(label: "in1Idx", fieldKey: "in1_idx"),
        _fieldGap,
        const NodeTextField(label: "in2Idx", fieldKey: "in2_idx")
      ]
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
        NodeTextField(label: "id", fieldKey: "id"),
        _fieldGap,
        NodeTextField(label: "featId", fieldKey: "feat_id"),
        _fieldGap,
        NodeTextField(label: "threshold", fieldKey: "threshold"),
        _fieldGap,
        NodeTextField(label: "trueIdx", fieldKey: "true_idx"),
        _fieldGap,
        NodeTextField(label: "falseIdx", fieldKey: "false_idx")
      ]
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
        NodeTextField(label: "id", fieldKey: "id"),
        _fieldGap,
        NodeTextField(label: "refIdx", fieldKey: "ref_idx"),
        _fieldGap,
        NodeTextField(label: "trueIdx", fieldKey: "true_idx"),
        _fieldGap,
        NodeTextField(label: "falseIdx", fieldKey: "false_idx")
      ]
    );
  }
}

class LogicNetContent extends StatelessWidget {
  const LogicNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const NodeCheckbox(label: "default", fieldKey: "default_value");
  }
}

class DecisionNetContent extends StatelessWidget {
  const DecisionNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(label: "maxTrail", fieldKey: "max_trail_len"),
        _fieldGap,
        NodeCheckbox(label: "default", fieldKey: "default_value")
      ]
    );
  }
}

class NetworkContent extends StatelessWidget {
  const NetworkContent({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      fieldKey: "type",
      options: networkTypes,
      optionLabel: (val) => val
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
        NodeTextField(label: "node", fieldKey: "node"),
        _fieldGap,
        NodeTextField(label: "input", fieldKey: "input"),
        _fieldGap,
        NodeTextField(label: "gate", fieldKey: "gate"),
        _fieldGap,
        NodeTextField(label: "recurrence", fieldKey: "recurrence"),
        _fieldGap,
        NodeTextField(label: "feedfwd", fieldKey: "feedforward"),
        _fieldGap,
        NodeTextField(label: "usedFeat", fieldKey: "used_feat"),
        _fieldGap,
        NodeTextField(label: "unusedFeat", fieldKey: "unused_feat")
      ]
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
        NodeTextField(label: "node", fieldKey: "node"),
        _fieldGap,
        NodeTextField(label: "branch", fieldKey: "branch"),
        _fieldGap,
        NodeTextField(label: "ref", fieldKey: "ref"),
        _fieldGap,
        NodeTextField(label: "leaf", fieldKey: "leaf"),
        _fieldGap,
        NodeTextField(label: "nonLeaf", fieldKey: "non_leaf"),
        _fieldGap,
        NodeTextField(label: "usedFeat", fieldKey: "used_feat"),
        _fieldGap,
        NodeTextField(label: "unusedFeat", fieldKey: "unused_feat")
      ]
    );
  }
}

class PenaltiesContent extends StatelessWidget {
  const PenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      fieldKey: "type",
      options: networkTypes,
      optionLabel: (val) => val
    );
  }
}
