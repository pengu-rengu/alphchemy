import "package:alphchemy/utils.dart";

class OhlcSeries {
  final List<double> timestamp;
  final List<double> open;
  final List<double> high;
  final List<double> low;
  final List<double> close;

  const OhlcSeries({required this.timestamp, required this.open, required this.high, required this.low, required this.close});

  factory OhlcSeries.fromJson(Map<String, dynamic> json) {
    return OhlcSeries(
      timestamp: doubleListFromJson(json["timestamp"]),
      open: doubleListFromJson(json["open"]),
      high: doubleListFromJson(json["high"]),
      low: doubleListFromJson(json["low"]),
      close: doubleListFromJson(json["close"])
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
  final Map<String, List<double>>? featTable;
  final String? error;

  const FeatureSetValues({required this.ohlc, required this.featTable, required this.error});

  factory FeatureSetValues.fromJson(Map<String, dynamic> json) {
    if (json.containsKey("error")) {
      return FeatureSetValues(ohlc: null, featTable: null, error: json["error"] as String);
    }

    final valuesJson = json["values"] as Map<String, dynamic>;
    final ohlcJson = valuesJson["ohlc"] as Map<String, dynamic>;
    final featuresJson = valuesJson["features"] as Map<String, dynamic>;
    final features = <String, List<double>>{};

    for (final entry in featuresJson.entries) {
      features[entry.key] = doubleListFromJson(entry.value);
    }

    return FeatureSetValues(
      ohlc: OhlcSeries.fromJson(ohlcJson),
      featTable: features,
      error: null
    );
  }

  Map<String, dynamic> toJson() {
    if (error != null) {
      return {"error": error};
    }

    final featsJson = <String, dynamic>{};
    for (final entry in featTable!.entries) {
      featsJson[entry.key] = entry.value;
    }

    final inner = <String, dynamic>{"features": featsJson};
    if (ohlc != null) {
      inner["ohlc"] = ohlc!.toJson();
    }

    return {"values": inner};
  }
}
