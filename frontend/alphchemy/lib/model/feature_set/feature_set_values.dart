import "package:alphchemy/utils.dart";

class OhlcSeries {
  final List<double> open;
  final List<double> high;
  final List<double> low;
  final List<double> close;

  const OhlcSeries({
    required this.open,
    required this.high,
    required this.low,
    required this.close
  });

  factory OhlcSeries.fromJson(Map<String, dynamic> json) {
    return OhlcSeries(
      open: toDoubleList(json["open"]),
      high: toDoubleList(json["high"]),
      low: toDoubleList(json["low"]),
      close: toDoubleList(json["close"])
    );
  }
}

class FeatureSetValues {
  final OhlcSeries ohlc;
  final Map<String, List<double>> featTable;
  final String? error;

  const FeatureSetValues({required this.ohlc, required this.featTable, this.error});

  factory FeatureSetValues.fromJson(Map<String, dynamic> json) {
    final ohlcJson = json["ohlc"] as Map<String, dynamic>? ?? const {};
    final featuresJson = json["features"] as Map<String, dynamic>? ?? const {};
    final rawError = json["error"];
    final features = <String, List<double>>{};

    for (final entry in featuresJson.entries) {
      features[entry.key] = toDoubleList(entry.value);
    }

    return FeatureSetValues(
      ohlc: OhlcSeries.fromJson(ohlcJson),
      featTable: features,
      error: rawError is String ? rawError : null
    );
  }
}
