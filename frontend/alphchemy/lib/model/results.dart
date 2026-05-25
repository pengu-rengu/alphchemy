import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/utils.dart";

class FoldResults {
  final double startTimestamp;
  final double endTimestamp;
  final double trainStartTimestamp;
  final double trainEndTimestamp;
  final double valStartTimestamp;
  final double valEndTimestamp;
  final double testStartTimestamp;
  final double testEndTimestamp;
  final OptimizerResults optResults;
  final BacktestResults trainResults;
  final BacktestResults valResults;
  final BacktestResults testResults;

  const FoldResults({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.trainStartTimestamp,
    required this.trainEndTimestamp,
    required this.valStartTimestamp,
    required this.valEndTimestamp,
    required this.testStartTimestamp,
    required this.testEndTimestamp,
    required this.optResults,
    required this.trainResults,
    required this.valResults,
    required this.testResults
  });

  factory FoldResults.fromJson(Map<String, dynamic> json) {
    final optJson = json["opt_results"] as Map<String, dynamic>;
    final trainJson = json["train_results"] as Map<String, dynamic>;
    final valJson = json["val_results"] as Map<String, dynamic>;
    final testJson = json["test_results"] as Map<String, dynamic>;

    return FoldResults(
      startTimestamp: getField<double>(json, "start_timestamp"),
      endTimestamp: getField<double>(json, "end_timestamp"),
      trainStartTimestamp: getField<double>(json, "train_start_timestamp"),
      trainEndTimestamp: getField<double>(json, "train_end_timestamp"),
      valStartTimestamp: getField<double>(json, "val_start_timestamp"),
      valEndTimestamp: getField<double>(json, "val_end_timestamp"),
      testStartTimestamp: getField<double>(json, "test_start_timestamp"),
      testEndTimestamp: getField<double>(json, "test_end_timestamp"),
      optResults: OptimizerResults.fromJson(optJson),
      trainResults: BacktestResults.fromJson(trainJson),
      valResults: BacktestResults.fromJson(valJson),
      testResults: BacktestResults.fromJson(testJson)
    );
  }

  BacktestResults resultsFor(ResultsSplit split) {
    switch (split) {
      case ResultsSplit.train:
        return trainResults;
      case ResultsSplit.val:
        return valResults;
      case ResultsSplit.test:
        return testResults;
    }
  }
}

class OptimizerResults {
  final int iters;
  final List<String> bestTrainSeq;
  final List<String> bestValSeq;
  final List<Improvement> trainImprovements;
  final List<Improvement> valImprovements;

  const OptimizerResults({
    required this.iters,
    required this.bestTrainSeq,
    required this.bestValSeq,
    required this.trainImprovements,
    required this.valImprovements
  });

  factory OptimizerResults.fromJson(Map<String, dynamic> json) {
    final bestTrainSeq = getField<List<String>>(json, "best_train_seq", fromJson: listFromJson<String>);
    final bestValSeq = getField<List<String>>(json, "best_val_seq", fromJson: listFromJson<String>);
    final trainList = json["train_improvements"] as List<dynamic>;
    final valList = json["val_improvements"] as List<dynamic>;
    final trainImprovements = <Improvement>[];
    final valImprovements = <Improvement>[];

    for (final raw in trainList) {
      final improvementJson = raw as Map<String, dynamic>;
      final improvement = Improvement.fromJson(improvementJson);
      trainImprovements.add(improvement);
    }

    for (final raw in valList) {
      final improvementJson = raw as Map<String, dynamic>;
      final improvement = Improvement.fromJson(improvementJson);
      valImprovements.add(improvement);
    }

    return OptimizerResults(
      iters: getField<int>(json, "iters"),
      bestTrainSeq: bestTrainSeq,
      bestValSeq: bestValSeq,
      trainImprovements: trainImprovements,
      valImprovements: valImprovements
    );
  }
}

class Improvement {
  final int iter;
  final double score;

  const Improvement({
    required this.iter,
    required this.score
  });

  factory Improvement.fromJson(Map<String, dynamic> json) {
    return Improvement(
      iter: getField<int>(json, "iter"),
      score: getField<double>(json, "score")
    );
  }
}

class BacktestResults {
  final bool isInvalid;
  final double excessSharpe;
  final double meanHoldTime;
  final double stdHoldTime;
  final int entries;
  final int totalExits;
  final int signalExits;
  final int stopLossExits;
  final int takeProfitExits;
  final int maxHoldExits;

  const BacktestResults({required this.isInvalid,
    required this.excessSharpe,
    required this.meanHoldTime,
    required this.stdHoldTime,
    required this.entries,
    required this.totalExits,
    required this.signalExits,
    required this.stopLossExits,
    required this.takeProfitExits,
    required this.maxHoldExits
  });

  factory BacktestResults.fromJson(Map<String, dynamic> json) {
    return BacktestResults(
      isInvalid: getField<bool>(json, "is_invalid"),
      excessSharpe: getField<double>(json, "excess_sharpe"),
      meanHoldTime: getField<double>(json, "mean_hold_time"),
      stdHoldTime: getField<double>(json, "std_hold_time"),
      entries: getField<int>(json, "entries"),
      totalExits: getField<int>(json, "total_exits"),
      signalExits: getField<int>(json, "signal_exits"),
      stopLossExits: getField<int>(json, "stop_loss_exits"),
      takeProfitExits: getField<int>(json, "take_profit_exits"),
      maxHoldExits: getField<int>(json, "max_hold_exits")
    );
  }
}

class ExperimentResults {
  final List<FoldResults> folds;
  final Experiment experiment;
  final String title;

  const ExperimentResults({
    required this.folds,
    required this.experiment,
    required this.title
  });

  factory ExperimentResults.fromJson(Map<String, dynamic> json) {
    final resultsJson = json["results"];
    final title = cleanTitle(getField<String>(json, "title"));
    final experimentJson = json["experiment"] as Map<String, dynamic>?;
    final experiment = experimentJson == null ? Experiment() : Experiment.fromJson(experimentJson);

    final resultsList = resultsJson as List<dynamic>;
    final folds = <FoldResults>[];

    for (final item in resultsList) {
      final foldJson = item as Map<String, dynamic>;
      final fold = FoldResults.fromJson(foldJson);
      folds.add(fold);
    }

    return ExperimentResults(
      folds: folds,
      experiment: experiment,
      title: title
    );
  }
}

enum ResultsSplit {
  train,
  val,
  test
}
