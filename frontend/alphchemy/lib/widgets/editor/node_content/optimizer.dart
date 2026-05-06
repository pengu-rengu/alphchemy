import "package:alphchemy/widgets/editor/node_fields.dart";
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
          fieldKey: "max_iters"
        ),
        _fieldGap,
        NodeTextField(
          label: "trainPat",
          fieldKey: "train_patience"
        ),
        _fieldGap,
        NodeTextField(
          label: "valPat",
          fieldKey: "val_patience"
        )
      ]
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
          fieldKey: "pop_size"
        ),
        _fieldGap,
        NodeTextField(
          label: "seqLen",
          fieldKey: "seq_len"
        ),
        _fieldGap,
        NodeTextField(
          label: "nElites",
          fieldKey: "n_elites"
        ),
        _fieldGap,
        NodeTextField(
          label: "mutRate",
          fieldKey: "mut_rate"
        ),
        _fieldGap,
        NodeTextField(
          label: "crossRate",
          fieldKey: "cross_rate"
        ),
        _fieldGap,
        NodeTextField(
          label: "tournSize",
          fieldKey: "tournament_size"
        )
      ]
    );
  }
}
