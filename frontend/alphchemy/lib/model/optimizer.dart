import 'package:alphchemy/model/json_helpers.dart';

class StopConds {
  final int maxIters;
  final int trainPatience;
  final int valPatience;

  StopConds({
    required this.maxIters,
    required this.trainPatience,
    required this.valPatience
  });

  factory StopConds.fromJson(Map<String, dynamic> json) {
    final maxIters = json['max_iters'] as int;
    final trainPatience = json['train_patience'] as int;
    final valPatience = json['val_patience'] as int;
    return StopConds(
      maxIters: maxIters,
      trainPatience: trainPatience,
      valPatience: valPatience
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_iters': maxIters,
      'train_patience': trainPatience,
      'val_patience': valPatience
    };
  }
}

class GeneticOpt {
  final int popSize;
  final int seqLen;
  final int nElites;
  final double mutRate;
  final double crossRate;
  final int tournSize;

  GeneticOpt({
    required this.popSize,
    required this.seqLen,
    required this.nElites,
    required this.mutRate,
    required this.crossRate,
    required this.tournSize
  });

  factory GeneticOpt.fromJson(Map<String, dynamic> json) {
    final popSize = json['pop_size'] as int;
    final seqLen = json['seq_len'] as int;
    final nElites = json['n_elites'] as int;
    final mutRate = doubleFromJson(json['mut_rate']);
    final crossRate = doubleFromJson(json['cross_rate']);
    final tournSize = json['tournament_size'] as int;
    return GeneticOpt(
      popSize: popSize,
      seqLen: seqLen,
      nElites: nElites,
      mutRate: mutRate,
      crossRate: crossRate,
      tournSize: tournSize
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pop_size': popSize,
      'seq_len': seqLen,
      'n_elites': nElites,
      'mut_rate': mutRate,
      'cross_rate': crossRate,
      'tournament_size': tournSize
    };
  }
}
