import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/utils.dart";

class StopConds extends NodeData {
  int maxIters;
  int trainPatience;
  int valPatience;

  @override
  NodeType get nodeType => NodeType.stopConds;

  @override
  int get fieldCount => 3;

  StopConds({this.maxIters = 0, this.trainPatience = 0, this.valPatience = 0, super.paramRefs});


  factory StopConds.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final maxIters = getField<int>(json, "max_iters", 0, paramRefs);
    final trainPatience = getField<int>(json, "train_patience", 0, paramRefs);
    final valPatience = getField<int>(json, "val_patience", 0, paramRefs);

    return StopConds(
      maxIters: maxIters,
      trainPatience: trainPatience,
      valPatience: valPatience,
      paramRefs: paramRefs
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
    final maxItersJson = assembleField("max_iters", maxIters);
    final trainPatienceJson = assembleField("train_patience", trainPatience);
    final valPatienceJson = assembleField("val_patience", valPatience);

    return {
      "max_iters": maxItersJson,
      "train_patience": trainPatienceJson,
      "val_patience": valPatienceJson
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
    this.tournSize = 0,
    super.paramRefs
  });

  factory GeneticOpt.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final popSize = getField<int>(json, "pop_size", 0, paramRefs);
    final seqLen = getField<int>(json, "seq_len", 0, paramRefs);
    final nElites = getField<int>(json, "n_elites", 0, paramRefs);
    final mutRate = getField<double>(json, "mut_rate", 0.0, paramRefs, doubleFromJson);
    final crossRate = getField<double>(json, "cross_rate", 0.0, paramRefs, doubleFromJson);
    final tournSize = getField<int>(json, "tournament_size", 0, paramRefs);

    return GeneticOpt(
      popSize: popSize,
      seqLen: seqLen,
      nElites: nElites,
      mutRate: mutRate,
      crossRate: crossRate,
      tournSize: tournSize,
      paramRefs: paramRefs
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
    final popSizeJson = assembleField("pop_size", popSize);
    final seqLenJson = assembleField("seq_len", seqLen);
    final nElitesJson = assembleField("n_elites", nElites);
    final mutRateJson = assembleField("mut_rate", mutRate);
    final crossRateJson = assembleField("cross_rate", crossRate);
    final tournSizeJson = assembleField("tournament_size", tournSize);

    return {
      "type": "genetic",
      "pop_size": popSizeJson,
      "seq_len": seqLenJson,
      "n_elites": nElitesJson,
      "mut_rate": mutRateJson,
      "cross_rate": crossRateJson,
      "tournament_size": tournSizeJson
    };
  }
}
