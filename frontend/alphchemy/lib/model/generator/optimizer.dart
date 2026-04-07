import "package:alphchemy/model/generator/graph_convert.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/node_ports.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class StopConds extends NodeObject {
  int maxIters;
  int trainPatience;
  int valPatience;

  @override
  NodeType get nodeType => NodeType.stopConds;

  StopConds({this.maxIters = 0, this.trainPatience = 0, this.valPatience = 0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "max_iters": maxIters = int.tryParse(text) ?? 0;
      case "train_patience": trainPatience = int.tryParse(text) ?? 0;
      case "val_patience": valPatience = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "max_iters" => maxIters.toString(),
      "train_patience" => trainPatience.toString(),
      "val_patience" => valPatience.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final maxIters = getField<int>(json, "max_iters", 0, paramRefs);
    final trainPatience = getField<int>(json, "train_patience", 0, paramRefs);
    final valPatience = getField<int>(json, "val_patience", 0, paramRefs);

    final data = StopConds(
      maxIters: maxIters,
      trainPatience: trainPatience,
      valPatience: valPatience,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as StopConds;

    final maxIters = assembleField(data.maxIters, "max_iters", data);
    final trainPatience = assembleField(data.trainPatience, "train_patience", data);
    final valPatience = assembleField(data.valPatience, "val_patience", data);
    
    return {
      "max_iters": maxIters,
      "train_patience": trainPatience,
      "val_patience": valPatience
    };
  }
}

class GeneticOpt extends NodeObject {
  int popSize;
  int seqLen;
  int nElites;
  double mutRate;
  double crossRate;
  int tournSize;

  @override
  NodeType get nodeType => NodeType.geneticOpt;

  GeneticOpt({this.popSize = 0, this.seqLen = 0, this.nElites = 0, this.mutRate = 0, this.crossRate = 0, this.tournSize = 0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "pop_size": popSize = int.tryParse(text) ?? 0;
      case "seq_len": seqLen = int.tryParse(text) ?? 0;
      case "n_elites": nElites = int.tryParse(text) ?? 0;
      case "mut_rate": mutRate = double.tryParse(text) ?? 0.0;
      case "cross_rate": crossRate = double.tryParse(text) ?? 0.0;
      case "tournament_size": tournSize = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

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

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};

    final popSize = getField<int>(json, "pop_size", 0, paramRefs);
    final seqLen = getField<int>(json, "seq_len", 0, paramRefs);
    final nElites = getField<int>(json, "n_elites", 0, paramRefs);
    final mutRate = getField<double>(json, "mut_rate", 0, paramRefs, doubleFromJson);
    final crossRate = getField<double>(json, "cross_rate", 0, paramRefs, doubleFromJson);
    final tournSize = getField<int>(json, "tournament_size", 0, paramRefs);

    final data = GeneticOpt(
      popSize: popSize,
      seqLen: seqLen,
      nElites: nElites,
      mutRate: mutRate,
      crossRate: crossRate,
      tournSize: tournSize,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as GeneticOpt;

    final popSize = assembleField(data.popSize, "pop_size", data);
    final seqLen = assembleField(data.seqLen, "seq_len", data);
    final nElites = assembleField(data.nElites, "n_elites", data);
    final mutRate = assembleField(data.mutRate, "mut_rate", data);
    final crossRate = assembleField(data.crossRate, "cross_rate", data);
    final tournSize = assembleField(data.tournSize, "tournament_size", data);

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
