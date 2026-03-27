import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/material.dart";
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

class StopCondsContent extends StatelessWidget {
  final StopConds data;

  const StopCondsContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "maxIters",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "maxIters",
            value: data.maxIters.toString(),
            onChanged: (val) => data.maxIters = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "trainPatience",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "trainPat",
            value: data.trainPatience.toString(),
            onChanged: (val) => data.trainPatience = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "valPatience",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "valPat",
            value: data.valPatience.toString(),
            onChanged: (val) => data.valPatience = int.tryParse(val) ?? 0
          )
        )
      ]
    );
  }
}

class GeneticOptContent extends StatelessWidget {
  final GeneticOpt data;

  const GeneticOptContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "popSize",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "popSize",
            value: data.popSize.toString(),
            onChanged: (val) => data.popSize = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "seqLen",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "seqLen",
            value: data.seqLen.toString(),
            onChanged: (val) => data.seqLen = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "nElites",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "nElites",
            value: data.nElites.toString(),
            onChanged: (val) => data.nElites = int.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "mutRate",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "mutRate",
            value: data.mutRate.toString(),
            onChanged: (val) => data.mutRate = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "crossRate",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "crossRate",
            value: data.crossRate.toString(),
            onChanged: (val) => data.crossRate = double.tryParse(val) ?? 0
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "tournSize",
          paramType: ParamType.intType,
          nodeData: data,
          child: NodeTextField(
            label: "tournSize",
            value: data.tournSize.toString(),
            onChanged: (val) => data.tournSize = int.tryParse(val) ?? 0
          )
        )
      ]
    );
  }
}
