import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/widgets/node_fields.dart";
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
    final data = StopConds(
      maxIters: json["max_iters"] as int,
      trainPatience: json["train_patience"] as int,
      valPatience: json["val_patience"] as int
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as StopConds;
    return {
      "max_iters": data.maxIters,
      "train_patience": data.trainPatience,
      "val_patience": data.valPatience
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
    final data = GeneticOpt(
      popSize: json["pop_size"] as int,
      seqLen: json["seq_len"] as int,
      nElites: json["n_elites"] as int,
      mutRate: (json["mut_rate"] as num).toDouble(),
      crossRate: (json["cross_rate"] as num).toDouble(),
      tournSize: json["tournament_size"] as int
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as GeneticOpt;
    return {
      "pop_size": data.popSize,
      "seq_len": data.seqLen,
      "n_elites": data.nElites,
      "mut_rate": data.mutRate,
      "cross_rate": data.crossRate,
      "tournament_size": data.tournSize
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
        NodeTextField(
          label: "maxIters",
          value: data.maxIters.toString(),
          onChanged: (val) => data.maxIters = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "trainPat",
          value: data.trainPatience.toString(),
          onChanged: (val) => data.trainPatience = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "valPat",
          value: data.valPatience.toString(),
          onChanged: (val) => data.valPatience = int.tryParse(val) ?? 0
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
        NodeTextField(
          label: "popSize",
          value: data.popSize.toString(),
          onChanged: (val) => data.popSize = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "seqLen",
          value: data.seqLen.toString(),
          onChanged: (val) => data.seqLen = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "nElites",
          value: data.nElites.toString(),
          onChanged: (val) => data.nElites = int.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "mutRate",
          value: data.mutRate.toString(),
          onChanged: (val) => data.mutRate = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "crossRate",
          value: data.crossRate.toString(),
          onChanged: (val) => data.crossRate = double.tryParse(val) ?? 0
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "tournSize",
          value: data.tournSize.toString(),
          onChanged: (val) => data.tournSize = int.tryParse(val) ?? 0
        )
      ]
    );
  }
}
