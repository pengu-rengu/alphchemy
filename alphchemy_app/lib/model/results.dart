import "dart:convert";

//import "package:alphchemy_app/model/experiment/experiment.dart";
import "package:alphchemy_app/utils.dart";

class FoldResults {
  final String trainStartTimestamp;
  final String trainEndTimestamp;
  final String valStartTimestamp;
  final String valEndTimestamp;
  final String testStartTimestamp;
  final String testEndTimestamp;
  final OptimizerResults optResults;
  final BacktestResults trainResults;
  final BacktestResults valResults;
  final BacktestResults testResults;

  const FoldResults({
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
      trainStartTimestamp: getField<String>(json, "train_start_timestamp"),
      trainEndTimestamp: getField<String>(json, "train_end_timestamp"),
      valStartTimestamp: getField<String>(json, "val_start_timestamp"),
      valEndTimestamp: getField<String>(json, "val_end_timestamp"),
      testStartTimestamp: getField<String>(json, "test_start_timestamp"),
      testEndTimestamp: getField<String>(json, "test_end_timestamp"),
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
  final String bestTrainNet;
  final List<String> bestValSeq;
  final String bestValNet;
  final List<Improvement> trainImps;
  final List<Improvement> valImps;

  const OptimizerResults({required this.iters, required this.bestTrainSeq, required this.bestTrainNet, required this.bestValSeq, required this.bestValNet, required this.trainImps, required this.valImps});

  static String formatNet(Map<String, dynamic> net) {
    const encoder = JsonEncoder.withIndent("  ");
    return encoder.convert(net);
  }

  factory OptimizerResults.fromJson(Map<String, dynamic> json) {
    final bestTrainSeq = getField<List<String>>(json, "best_train_seq", fromJson: listFromJson<String>);
    final bestTrainNetJson = getField<Map<String, dynamic>>(json, "best_train_net");
    final bestTrainNet = OptimizerResults.formatNet(bestTrainNetJson);
    final bestValSeq = getField<List<String>>(json, "best_val_seq", fromJson: listFromJson<String>);
    final bestValNetJson = getField<Map<String, dynamic>>(json, "best_val_net");
    final bestValNet = OptimizerResults.formatNet(bestValNetJson);
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
      bestTrainNet: bestTrainNet,
      bestValSeq: bestValSeq,
      bestValNet: bestValNet,
      trainImps: trainImprovements,
      valImps: valImprovements
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

enum BacktestMetric {
  sharpe,
  excessSharpe,
  maxDrawdown,
  meanHoldTime,
  stdHoldTime,
  totalEntries,
  totalExits,
  signalExits,
  stopLossExits,
  takeProfitExits,
  maxHoldExits;

  String get displayName => switch (this) {
    BacktestMetric.sharpe => "Sharpe",
    BacktestMetric.excessSharpe => "Excess Sharpe",
    BacktestMetric.maxDrawdown => "Max Drawdown",
    BacktestMetric.meanHoldTime => "Mean Hold Time",
    BacktestMetric.stdHoldTime => "Std Dev Hold Time",
    BacktestMetric.totalEntries => "Total Entries",
    BacktestMetric.totalExits => "Total Exits",
    BacktestMetric.signalExits => "Signal Exits",
    BacktestMetric.stopLossExits => "Stop Loss Exits",
    BacktestMetric.takeProfitExits => "Take Profit Exits",
    BacktestMetric.maxHoldExits => "Max Hold Exits"
  };

  static BacktestMetric fromKey(String key) => switch (key) {
    "sharpe" => BacktestMetric.sharpe,
    "excess_sharpe" => BacktestMetric.excessSharpe,
    "max_drawdown" => BacktestMetric.maxDrawdown,
    "mean_hold_time" => BacktestMetric.meanHoldTime,
    "std_hold_time" => BacktestMetric.stdHoldTime,
    "total_entries" => BacktestMetric.totalEntries,
    "total_exits" => BacktestMetric.totalExits,
    "signal_exits" => BacktestMetric.signalExits,
    "stop_loss_exits" => BacktestMetric.stopLossExits,
    "take_profit_exits" => BacktestMetric.takeProfitExits,
    "max_hold_exits" => BacktestMetric.maxHoldExits,
    _ => throw StateError("invalid backtest metric: $key")
  };
}

class BacktestResults {
  final bool isInvalid;
  final int nBars;
  final Map<BacktestMetric, double> metrics;
  final List<double> equityCurve;

  const BacktestResults({
    required this.isInvalid,
    required this.nBars,
    required this.metrics,
    required this.equityCurve
  });

  factory BacktestResults.fromJson(Map<String, dynamic> json) {
    final metricsJson = json["metrics"] as Map<String, dynamic>;
    final metrics = <BacktestMetric, double>{};

    for (final entry in metricsJson.entries) {
      final metric = BacktestMetric.fromKey(entry.key);
      metrics[metric] = (entry.value as num).toDouble();
    }

    return BacktestResults(
      isInvalid: getField<bool>(json, "is_invalid"),
      nBars: getField<int>(json, "n_bars"),
      metrics: metrics,
      equityCurve: getField<List<double>>(json, "equity_curve", fromJson: doubleListFromJson)
    );
  }
}

class ExperimentResults {
  final List<FoldResults> folds;
  final String source;
  final String experiment;
  final String title;
  final String? userId;
  final bool isPublic;

  const ExperimentResults({
    required this.folds,
    required this.source,
    required this.experiment,
    required this.title,
    required this.userId,
    required this.isPublic
  });

  factory ExperimentResults.fromJson(Map<String, dynamic> json) {
    final resultsJson = json["results"];
    final title = getField<String>(json, "title");
    final cleanedTitle = cleanTitle(title);
    final source = getField<String>(json, "source");
    const encoder = JsonEncoder.withIndent("  ");
    final experiment = encoder.convert(json["experiment"] ?? {});

    final resultsList = resultsJson as List<dynamic>;
    final folds = <FoldResults>[];

    for (final item in resultsList) {
      final fold = FoldResults.fromJson(item as Map<String, dynamic>);
      folds.add(fold);
    }

    return ExperimentResults(
      folds: folds,
      source: source,
      experiment: experiment,
      title: cleanedTitle,
      userId: json["user_id"] as String?,
      isPublic: json["is_public"] as bool
    );
  }

}

enum ResultsSplit {
  train,
  val,
  test
}
