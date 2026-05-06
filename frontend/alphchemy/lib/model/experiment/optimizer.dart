import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/utils.dart";

class StopConds extends NodeData {
  int maxIters;
  int trainPatience;
  int valPatience;

  @override
  NodeType get nodeType => NodeType.stopConds;

  @override
  int get fieldCount => 3;

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
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "max_iters":
        maxIters = int.tryParse(text) ?? 0;
      case "train_patience":
        trainPatience = int.tryParse(text) ?? 0;
      case "val_patience":
        valPatience = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
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
  int get fieldCount => 6;

  GeneticOpt({
    this.popSize = 0,
    this.seqLen = 0,
    this.nElites = 0,
    this.mutRate = 0.0,
    this.crossRate = 0.0,
    this.tournSize = 0
  });

  factory GeneticOpt.fromJson(Map<String, dynamic> json) {
    final popSize = getField<int>(json, "pop_size", 0);
    final seqLen = getField<int>(json, "seq_len", 0);
    final nElites = getField<int>(json, "n_elites", 0);
    final mutRate = getField<double>(json, "mut_rate", 0.0, doubleFromJson);
    final crossRate = getField<double>(json, "cross_rate", 0.0, doubleFromJson);
    final tournSize = getField<int>(json, "tournament_size", 0);

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
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
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
      case "tournament_size":
        tournSize = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "pop_size" => popSize.toString(),
      "seq_len" => seqLen.toString(),
      "n_elites" => nElites.toString(),
      "mut_rate" => mutRate.toString(),
      "cross_rate" => crossRate.toString(),
      "tournament_size" => tournSize.toString(),
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
      "tournament_size": tournSize
    };
  }
}
