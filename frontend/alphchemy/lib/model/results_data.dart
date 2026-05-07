sealed class ResultsPayload {
  const ResultsPayload();

  factory ResultsPayload.fromJson(Map<String, dynamic> json) {
    if (json.containsKey("error")) {
      return ErrorResults.fromJson(json);
    }

    return SuccessResults.fromJson(json);
  }
}

class ErrorResults extends ResultsPayload {
  final String error;
  final bool isInternal;

  const ErrorResults({
    required this.error,
    required this.isInternal
  });

  factory ErrorResults.fromJson(Map<String, dynamic> json) {
    final error = json["error"] as String? ?? "Unknown error";
    final isInternal = json["is_internal"] as bool? ?? false;

    return ErrorResults(
      error: error,
      isInternal: isInternal
    );
  }
}

class SuccessResults extends ResultsPayload {
  final double overallExcessSharpe;
  final double invalidFrac;
  final List<FoldResults> foldResults;

  const SuccessResults({
    required this.overallExcessSharpe,
    required this.invalidFrac,
    required this.foldResults
  });

  factory SuccessResults.fromJson(Map<String, dynamic> json) {
    final foldJsonList = ResultsJson.mapList(json["fold_results"]);
    final foldResults = <FoldResults>[];

    for (final foldJson in foldJsonList) {
      final fold = FoldResults.fromJson(foldJson);
      foldResults.add(fold);
    }

    return SuccessResults(
      overallExcessSharpe: ResultsJson.doubleValue(json["overall_excess_sharpe"]),
      invalidFrac: ResultsJson.doubleValue(json["invalid_frac"]),
      foldResults: foldResults
    );
  }
}

class FoldResults {
  final int startIdx;
  final int endIdx;
  final OptimizerResults optResults;
  final BacktestResults trainResults;
  final BacktestResults valResults;
  final BacktestResults testResults;

  const FoldResults({
    required this.startIdx,
    required this.endIdx,
    required this.optResults,
    required this.trainResults,
    required this.valResults,
    required this.testResults
  });

  factory FoldResults.fromJson(Map<String, dynamic> json) {
    final optJson = ResultsJson.mapValue(json["opt_results"]);
    final trainJson = ResultsJson.mapValue(json["train_results"]);
    final valJson = ResultsJson.mapValue(json["val_results"]);
    final testJson = ResultsJson.mapValue(json["test_results"]);

    return FoldResults(
      startIdx: ResultsJson.intValue(json["start_idx"]),
      endIdx: ResultsJson.intValue(json["end_idx"]),
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
  final List<String> bestSeq;
  final List<Improvement> trainImprovements;
  final List<Improvement> valImprovements;

  const OptimizerResults({
    required this.iters,
    required this.bestSeq,
    required this.trainImprovements,
    required this.valImprovements
  });

  factory OptimizerResults.fromJson(Map<String, dynamic> json) {
    final bestSeq = ResultsJson.stringList(json["best_seq"]);
    final trainJsonList = ResultsJson.mapList(json["train_improvements"]);
    final valJsonList = ResultsJson.mapList(json["val_improvements"]);
    final trainImprovements = <Improvement>[];
    final valImprovements = <Improvement>[];

    for (final improvementJson in trainJsonList) {
      final improvement = Improvement.fromJson(improvementJson);
      trainImprovements.add(improvement);
    }

    for (final improvementJson in valJsonList) {
      final improvement = Improvement.fromJson(improvementJson);
      valImprovements.add(improvement);
    }

    return OptimizerResults(
      iters: ResultsJson.intValue(json["iters"]),
      bestSeq: bestSeq,
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
      iter: ResultsJson.intValue(json["iter"]),
      score: ResultsJson.doubleValue(json["score"])
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

  const BacktestResults({
    required this.isInvalid,
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
      isInvalid: json["is_invalid"] as bool? ?? false,
      excessSharpe: ResultsJson.doubleValue(json["excess_sharpe"]),
      meanHoldTime: ResultsJson.doubleValue(json["mean_hold_time"]),
      stdHoldTime: ResultsJson.doubleValue(json["std_hold_time"]),
      entries: ResultsJson.intValue(json["entries"]),
      totalExits: ResultsJson.intValue(json["total_exits"]),
      signalExits: ResultsJson.intValue(json["signal_exits"]),
      stopLossExits: ResultsJson.intValue(json["stop_loss_exits"]),
      takeProfitExits: ResultsJson.intValue(json["take_profit_exits"]),
      maxHoldExits: ResultsJson.intValue(json["max_hold_exits"])
    );
  }
}

class ExperimentResultsRecord {
  final ResultsPayload results;

  const ExperimentResultsRecord({
    required this.results
  });

  factory ExperimentResultsRecord.fromJson(Map<String, dynamic> json) {
    final resultsJson = ResultsJson.mapValue(json["results"]);
    final results = ResultsPayload.fromJson(resultsJson);

    return ExperimentResultsRecord(
      results: results
    );
  }
}

enum ResultsSplit {
  train,
  val,
  test
}

class ResultsJson {
  const ResultsJson();

  static Map<String, dynamic> mapValue(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }

    return value as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> mapList(dynamic value) {
    final rawList = value as List<dynamic>? ?? <dynamic>[];
    final maps = <Map<String, dynamic>>[];

    for (final rawItem in rawList) {
      final mapItem = rawItem as Map<String, dynamic>;
      maps.add(mapItem);
    }

    return maps;
  }

  static List<String> stringList(dynamic value) {
    final rawList = value as List<dynamic>? ?? <dynamic>[];
    final strings = <String>[];

    for (final rawItem in rawList) {
      final stringItem = rawItem as String;
      strings.add(stringItem);
    }

    return strings;
  }

  static int intValue(dynamic value) {
    final number = value as num? ?? 0;
    return number.toInt();
  }

  static double doubleValue(dynamic value) {
    final number = value as num? ?? 0.0;
    return number.toDouble();
  }
}
