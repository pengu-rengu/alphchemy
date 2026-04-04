import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class StopCondsContent extends StatelessWidget {
  const StopCondsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "maxIters", paramType: ParamType.intType, child: NodeTextField(label: "maxIters", fieldKey: "maxIters")),
        _fieldGap,
        ParamField(fieldKey: "trainPatience", paramType: ParamType.intType, child: NodeTextField(label: "trainPat", fieldKey: "trainPatience")),
        _fieldGap,
        ParamField(fieldKey: "valPatience", paramType: ParamType.intType, child: NodeTextField(label: "valPat", fieldKey: "valPatience"))
      ]
    );
  }
}

class GeneticOptContent extends StatelessWidget {
  const GeneticOptContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(fieldKey: "popSize", paramType: ParamType.intType, child: NodeTextField(label: "popSize", fieldKey: "popSize")),
        _fieldGap,
        ParamField(fieldKey: "seqLen", paramType: ParamType.intType, child: NodeTextField(label: "seqLen", fieldKey: "seqLen")),
        _fieldGap,
        ParamField(fieldKey: "nElites", paramType: ParamType.intType, child: NodeTextField(label: "nElites", fieldKey: "nElites")),
        _fieldGap,
        ParamField(fieldKey: "mutRate", paramType: ParamType.floatType, child: NodeTextField(label: "mutRate", fieldKey: "mutRate")),
        _fieldGap,
        ParamField(fieldKey: "crossRate", paramType: ParamType.floatType, child: NodeTextField(label: "crossRate", fieldKey: "crossRate")),
        _fieldGap,
        ParamField(fieldKey: "tournSize", paramType: ParamType.intType, child: NodeTextField(label: "tournSize", fieldKey: "tournSize"))
      ]
    );
  }
}
