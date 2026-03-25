import 'package:alphchemy/model/node_object.dart';

class StopConds extends NodeObject {
  int maxIters;
  int trainPatience;
  int valPatience;

  @override
  String get nodeType => 'stop_conds';

  StopConds({
    required this.maxIters,
    required this.trainPatience,
    required this.valPatience
  });
}

class GeneticOpt extends NodeObject {
  int popSize;
  int seqLen;
  int nElites;
  double mutRate;
  double crossRate;
  int tournSize;

  @override
  String get nodeType => 'genetic_opt';

  GeneticOpt({
    required this.popSize,
    required this.seqLen,
    required this.nElites,
    required this.mutRate,
    required this.crossRate,
    required this.tournSize
  });
}
