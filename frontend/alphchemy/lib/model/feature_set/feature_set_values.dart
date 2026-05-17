import "package:alphchemy/utils.dart";

class OhlcSeries {
  final List<double> timestamp;
  final List<double> open;
  final List<double> high;
  final List<double> low;
  final List<double> close;

  const OhlcSeries({required this.timestamp, required this.open, required this.high, required this.low, required this.close});

  factory OhlcSeries.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json["timestamp"];
    return OhlcSeries(
      timestamp: rawTimestamp is List ? toDoubleList(rawTimestamp) : const <double>[],
      open: toDoubleList(json["open"]),
      high: toDoubleList(json["high"]),
      low: toDoubleList(json["low"]),
      close: toDoubleList(json["close"])
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "timestamp": timestamp,
      "open": open,
      "high": high,
      "low": low,
      "close": close
    };
  }
}

class FeatureSetValues {
  final OhlcSeries? ohlc;
  final Map<String, List<double>> featTable;
  final String? error;

  const FeatureSetValues({required this.ohlc, required this.featTable, this.error});

  factory FeatureSetValues.fromJson(Map<String, dynamic> json) {
    final rawError = json["error"];
    final rawOhlc = json["ohlc"];
    final rawFeatures = json["features"];
    final ohlcJson = rawOhlc is Map ? Map<String, dynamic>.from(rawOhlc) : null;
    final featuresJson = rawFeatures is Map ? Map<String, dynamic>.from(rawFeatures) : const <String, dynamic>{};
    final features = <String, List<double>>{};

    for (final entry in featuresJson.entries) {
      features[entry.key] = toDoubleList(entry.value);
    }

    return FeatureSetValues(
      ohlc: ohlcJson == null ? null : OhlcSeries.fromJson(ohlcJson),
      featTable: features,
      error: rawError is String ? rawError : null
    );
  }

  Map<String, dynamic> toJson() {
    final featsJson = <String, dynamic>{};
    for (final entry in featTable.entries) {
      featsJson[entry.key] = entry.value;
    }

    final json = <String, dynamic>{"features": featsJson};

    if (ohlc != null) {
      json["ohlc"] = ohlc!.toJson();
    }

    if (error != null) {
      json["error"] = error;
    }

    return json;
  }
}
