import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

class StopConds extends NodeObject {
  int maxIters;
  int trainPatience;
  int valPatience;

  @override
  String get nodeType => "stop_conds";

  StopConds({
    this.maxIters = 100,
    this.trainPatience = 10,
    this.valPatience = 5
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "maxIters": maxIters = int.tryParse(text) ?? 0;
      case "trainPatience": trainPatience = int.tryParse(text) ?? 0;
      case "valPatience": valPatience = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "maxIters" => maxIters.toString(),
      "trainPatience" => trainPatience.toString(),
      "valPatience" => valPatience.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final data = StopConds(
      maxIters: intOrDefault(json, "max_iters", "maxIters", 100, refs),
      trainPatience: intOrDefault(json, "train_patience", "trainPatience", 10, refs),
      valPatience: intOrDefault(json, "val_patience", "valPatience", 5, refs)
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as StopConds;
    return {
      "max_iters": assembleField(data.maxIters, "maxIters", data.paramRefs),
      "train_patience": assembleField(data.trainPatience, "trainPatience", data.paramRefs),
      "val_patience": assembleField(data.valPatience, "valPatience", data.paramRefs)
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
  String get nodeType => "genetic_opt";

  GeneticOpt({
    this.popSize = 50,
    this.seqLen = 10,
    this.nElites = 5,
    this.mutRate = 0.1,
    this.crossRate = 0.7,
    this.tournSize = 3
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "popSize": popSize = int.tryParse(text) ?? 0;
      case "seqLen": seqLen = int.tryParse(text) ?? 0;
      case "nElites": nElites = int.tryParse(text) ?? 0;
      case "mutRate": mutRate = double.tryParse(text) ?? 0.0;
      case "crossRate": crossRate = double.tryParse(text) ?? 0.0;
      case "tournSize": tournSize = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "popSize" => popSize.toString(),
      "seqLen" => seqLen.toString(),
      "nElites" => nElites.toString(),
      "mutRate" => mutRate.toString(),
      "crossRate" => crossRate.toString(),
      "tournSize" => tournSize.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final data = GeneticOpt(
      popSize: intOrDefault(json, "pop_size", "popSize", 50, refs),
      seqLen: intOrDefault(json, "seq_len", "seqLen", 10, refs),
      nElites: intOrDefault(json, "n_elites", "nElites", 5, refs),
      mutRate: doubleOrDefault(json, "mut_rate", "mutRate", 0.1, refs),
      crossRate: doubleOrDefault(json, "cross_rate", "crossRate", 0.7, refs),
      tournSize: intOrDefault(json, "tournament_size", "tournSize", 3, refs)
    );
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as GeneticOpt;
    return {
      "type": "genetic",
      "pop_size": assembleField(data.popSize, "popSize", data.paramRefs),
      "seq_len": assembleField(data.seqLen, "seqLen", data.paramRefs),
      "n_elites": assembleField(data.nElites, "nElites", data.paramRefs),
      "mut_rate": assembleField(data.mutRate, "mutRate", data.paramRefs),
      "cross_rate": assembleField(data.crossRate, "crossRate", data.paramRefs),
      "tournament_size": assembleField(data.tournSize, "tournSize", data.paramRefs)
    };
  }
}
