import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class NodePtrContent extends StatelessWidget {
  const NodePtrContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "anchor",
          paramType: ParamType.stringType,
          child: NodeDropdown<Anchor>(
            label: "anchor",
            fieldKey: "anchor",
            options: Anchor.values,
            labelFor: (val) => val.name
          )
        ),
        _fieldGap,
        ParamField(fieldKey: "idx", paramType: ParamType.intType, child: NodeTextField(label: "idx", fieldKey: "idx"))
      ]
    );
  }
}

class InputNodeContent extends StatelessWidget {
  const InputNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        _fieldGap,
        NodeTextField(label: "idx", fieldKey: "idx"),
        _fieldGap,
        ParamField(fieldKey: "featId", paramType: ParamType.stringType, child: NodeTextField(label: "featId", fieldKey: "featId")),
        _fieldGap,
        ParamField(fieldKey: "threshold", paramType: ParamType.floatType, child: NodeTextField(label: "threshold", fieldKey: "threshold"))
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
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        _fieldGap,
        NodeTextField(label: "idx", fieldKey: "idx"),
        _fieldGap,
        ParamField(
          fieldKey: "gate",
          paramType: ParamType.stringType,
          child: NodeDropdown<Gate>(
            label: "gate",
            fieldKey: "gate",
            options: Gate.values,
            labelFor: (val) => val.name
          )
        ),
        _fieldGap,
        ParamField(fieldKey: "in1Idx", paramType: ParamType.intType, child: NodeTextField(label: "in1Idx", fieldKey: "in1Idx")),
        _fieldGap,
        ParamField(fieldKey: "in2Idx", paramType: ParamType.intType, child: NodeTextField(label: "in2Idx", fieldKey: "in2Idx"))
      ]
    );
  }
}

class BranchNodeContent extends StatelessWidget {
  const BranchNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        _fieldGap,
        NodeTextField(label: "idx", fieldKey: "idx"),
        _fieldGap,
        ParamField(fieldKey: "featId", paramType: ParamType.stringType, child: NodeTextField(label: "featId", fieldKey: "featId")),
        _fieldGap,
        ParamField(fieldKey: "threshold", paramType: ParamType.floatType, child: NodeTextField(label: "threshold", fieldKey: "threshold")),
        _fieldGap,
        ParamField(fieldKey: "trueIdx", paramType: ParamType.intType, child: NodeTextField(label: "trueIdx", fieldKey: "trueIdx")),
        _fieldGap,
        ParamField(fieldKey: "falseIdx", paramType: ParamType.intType, child: NodeTextField(label: "falseIdx", fieldKey: "falseIdx"))
      ]
    );
  }
}

class RefNodeContent extends StatelessWidget {
  const RefNodeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeId", paramType: ParamType.stringType, child: NodeTextField(label: "id", fieldKey: "nodeId")),
        _fieldGap,
        NodeTextField(label: "idx", fieldKey: "idx"),
        _fieldGap,
        ParamField(fieldKey: "refIdx", paramType: ParamType.intType, child: NodeTextField(label: "refIdx", fieldKey: "refIdx")),
        _fieldGap,
        ParamField(fieldKey: "trueIdx", paramType: ParamType.intType, child: NodeTextField(label: "trueIdx", fieldKey: "trueIdx")),
        _fieldGap,
        ParamField(fieldKey: "falseIdx", paramType: ParamType.intType, child: NodeTextField(label: "falseIdx", fieldKey: "falseIdx"))
      ]
    );
  }
}

class LogicNetContent extends StatelessWidget {
  const LogicNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeSelection", paramType: ParamType.stringListType, child: NodeTextField(label: "nodeSel", fieldKey: "nodeSelection")),
        _fieldGap,
        ParamField(fieldKey: "defaultValue", paramType: ParamType.boolType, child: NodeCheckbox(label: "default", fieldKey: "defaultValue"))
      ]
    );
  }
}

class DecisionNetContent extends StatelessWidget {
  const DecisionNetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "nodeSelection", paramType: ParamType.stringListType, child: NodeTextField(label: "nodeSel", fieldKey: "nodeSelection")),
        _fieldGap,
        ParamField(fieldKey: "maxTrailLen", paramType: ParamType.intType, child: NodeTextField(label: "maxTrail", fieldKey: "maxTrailLen")),
        _fieldGap,
        ParamField(fieldKey: "defaultValue", paramType: ParamType.boolType, child: NodeCheckbox(label: "default", fieldKey: "defaultValue"))
      ]
    );
  }
}

class LogicPenaltiesContent extends StatelessWidget {
  const LogicPenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "node", paramType: ParamType.floatType, child: NodeTextField(label: "node", fieldKey: "node")),
        _fieldGap,
        ParamField(fieldKey: "input", paramType: ParamType.floatType, child: NodeTextField(label: "input", fieldKey: "input")),
        _fieldGap,
        ParamField(fieldKey: "gate", paramType: ParamType.floatType, child: NodeTextField(label: "gate", fieldKey: "gate")),
        _fieldGap,
        ParamField(fieldKey: "recurrence", paramType: ParamType.floatType, child: NodeTextField(label: "recurrence", fieldKey: "recurrence")),
        _fieldGap,
        ParamField(fieldKey: "feedforward", paramType: ParamType.floatType, child: NodeTextField(label: "feedfwd", fieldKey: "feedforward")),
        _fieldGap,
        ParamField(fieldKey: "usedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "usedFeat", fieldKey: "usedFeat")),
        _fieldGap,
        ParamField(fieldKey: "unusedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "unusedFeat", fieldKey: "unusedFeat"))
      ]
    );
  }
}

class DecisionPenaltiesContent extends StatelessWidget {
  const DecisionPenaltiesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "node", paramType: ParamType.floatType, child: NodeTextField(label: "node", fieldKey: "node")),
        _fieldGap,
        ParamField(fieldKey: "branch", paramType: ParamType.floatType, child: NodeTextField(label: "branch", fieldKey: "branch")),
        _fieldGap,
        ParamField(fieldKey: "ref", paramType: ParamType.floatType, child: NodeTextField(label: "ref", fieldKey: "ref")),
        _fieldGap,
        ParamField(fieldKey: "leaf", paramType: ParamType.floatType, child: NodeTextField(label: "leaf", fieldKey: "leaf")),
        _fieldGap,
        ParamField(fieldKey: "nonLeaf", paramType: ParamType.floatType, child: NodeTextField(label: "nonLeaf", fieldKey: "nonLeaf")),
        _fieldGap,
        ParamField(fieldKey: "usedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "usedFeat", fieldKey: "usedFeat")),
        _fieldGap,
        ParamField(fieldKey: "unusedFeat", paramType: ParamType.floatType, child: NodeTextField(label: "unusedFeat", fieldKey: "unusedFeat"))
      ]
    );
  }
}
