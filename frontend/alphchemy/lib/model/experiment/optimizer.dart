import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

class StopConds extends NodeData {
  int maxIters;
  int trainPatience;
  int valPatience;

  @override
  NodeType get nodeType => NodeType.stopConds;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Max Iterations", field: "max_iters"),
    NodeTextField(label: "Train Patience", field: "train_patience"),
    NodeTextField(label: "Validation Patience", field: "val_patience")
  ];

  StopConds({this.maxIters = 0, this.trainPatience = 0, this.valPatience = 0});

  factory StopConds.fromJson(Map<String, dynamic> json) {
    final maxIters = getField<int>(json, "max_iters", 0);
    final trainPatience = getField<int>(json, "train_patience", 0);
    final valPatience = getField<int>(json, "val_patience", 0);

    return StopConds(
      maxIters: maxIters,
      trainPatience: trainPatience,
      valPatience: valPatience
    );
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "max_iters":
        maxIters = int.tryParse(text) ?? 0;
      case "train_patience":
        trainPatience = int.tryParse(text) ?? 0;
      case "val_patience":
        valPatience = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "max_iters" => maxIters.toString(),
      "train_patience" => trainPatience.toString(),
      "val_patience" => valPatience.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "max_iters": maxIters,
      "train_patience": trainPatience,
      "val_patience": valPatience
    };
  }
}

class GeneticOpt extends NodeData {
  int popSize;
  int seqLen;
  int nElites;
  double mutRate;
  double crossRate;
  int tournSize;

  @override
  NodeType get nodeType => NodeType.geneticOpt;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Population Size", field: "pop_size"),
    NodeTextField(label: "Sequence Length", field: "seq_len"),
    NodeTextField(label: "# Of Elites", field: "n_elites"),
    NodeTextField(label: "Mutation Rate", field: "mut_rate"),
    NodeTextField(label: "Crossover Rate", field: "cross_rate"),
    NodeTextField(label: "Tournament Size", field: "tourn_size")
  ];

  GeneticOpt({this.popSize = 0, this.seqLen = 0, this.nElites = 0, this.mutRate = 0.0, this.crossRate = 0.0, this.tournSize = 0});

  factory GeneticOpt.fromJson(Map<String, dynamic> json) {
    final popSize = getField<int>(json, "pop_size", 0);
    final seqLen = getField<int>(json, "seq_len", 0);
    final nElites = getField<int>(json, "n_elites", 0);
    final mutRate = getField<double>(json, "mut_rate", 0.0, doubleFromJson);
    final crossRate = getField<double>(json, "cross_rate", 0.0, doubleFromJson);
    final tournSize = getField<int>(json, "tourn_size", 0);

    return GeneticOpt(
      popSize: popSize,
      seqLen: seqLen,
      nElites: nElites,
      mutRate: mutRate,
      crossRate: crossRate,
      tournSize: tournSize
    );
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "pop_size":
        popSize = int.tryParse(text) ?? 0;
      case "seq_len":
        seqLen = int.tryParse(text) ?? 0;
      case "n_elites":
        nElites = int.tryParse(text) ?? 0;
      case "mut_rate":
        mutRate = double.tryParse(text) ?? 0.0;
      case "cross_rate":
        crossRate = double.tryParse(text) ?? 0.0;
      case "tourn_size":
        tournSize = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "pop_size" => popSize.toString(),
      "seq_len" => seqLen.toString(),
      "n_elites" => nElites.toString(),
      "mut_rate" => mutRate.toString(),
      "cross_rate" => crossRate.toString(),
      "tourn_size" => tournSize.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "genetic",
      "pop_size": popSize,
      "seq_len": seqLen,
      "n_elites": nElites,
      "mut_rate": mutRate,
      "cross_rate": crossRate,
      "tourn_size": tournSize
    };
  }
}
