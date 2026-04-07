import "package:alphchemy/model/generator/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class StopCondsContent extends StatelessWidget {
  const StopCondsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "maxIters",
          fieldKey: "max_iters",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "trainPat",
          fieldKey: "train_patience",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "valPat",
          fieldKey: "val_patience",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}

class GeneticOptContent extends StatelessWidget {
  const GeneticOptContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "popSize",
          fieldKey: "pop_size",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "seqLen",
          fieldKey: "seq_len",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "nElites",
          fieldKey: "n_elites",
          paramType: ParamType.intType,
        ),
        _fieldGap,
        NodeTextField(
          label: "mutRate",
          fieldKey: "mut_rate",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "crossRate",
          fieldKey: "cross_rate",
          paramType: ParamType.floatType,
        ),
        _fieldGap,
        NodeTextField(
          label: "tournSize",
          fieldKey: "tournament_size",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}
