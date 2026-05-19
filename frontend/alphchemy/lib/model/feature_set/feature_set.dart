import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/model/feature_set/feature_set_values.dart";
import "package:alphchemy/utils.dart";

const featureNodeTypes = [
  NodeType.constant,
  NodeType.rawReturns,
  NodeType.normalizedSma,
  NodeType.normalizedEma,
  NodeType.normalizedMacd,
  NodeType.rsi,
  NodeType.normalizedBb,
  NodeType.stochastic,
  NodeType.atr,
  NodeType.roc,
  NodeType.normalizedDc
];

NodeData? featureFromJson(Map<String, dynamic> json) {
  final feature = json["feature"];
  if (feature is! String) return null;

  switch (feature) {
    case "constant":
      return Constant.fromJson(json);
    case "raw_returns":
      return RawReturns.fromJson(json);
    case "normalized_sma":
      return NormalizedSMA.fromJson(json);
    case "normalized_ema":
      return NormalizedEMA.fromJson(json);
    case "normalized_macd":
      return NormalizedMACD.fromJson(json);
    case "rsi":
      return RSI.fromJson(json);
    case "normalized_bb":
      return NormalizedBB.fromJson(json);
    case "stochastic":
      return Stochastic.fromJson(json);
    case "normalized_atr":
      return NormalizedATR.fromJson(json);
    case "roc":
      return ROC.fromJson(json);
    case "normalized_dc":
      return NormalizedDC.fromJson(json);
    default:
      return null;
  }
}

class FeatureSet {
  int id;
  String title;
  FeatureSetValues? values;
  FeatureSetStatus status;
  double startTimestamp;
  double endTimestamp;
  final List<NodeData> feats;

  FeatureSet({this.id = 0, this.title = "Untitled Feature Set", this.values, this.status = FeatureSetStatus.idle, this.startTimestamp = 0.0, this.endTimestamp = 0.0, List<NodeData>? feats}) : feats = feats ?? <NodeData>[];

  factory FeatureSet.fromJson(Map<String, dynamic> row) {
    final rawFeatures = row["features"] as Map;
    final features = Map<String, dynamic>.from(rawFeatures);
    final start = getField<double>(row, "start_timestamp");
    final end = getField<double>(row, "end_timestamp");
    final valuesField = row["values"];
    final values = valuesField is Map ? FeatureSetValues.fromJson(Map<String, dynamic>.from(valuesField)) : null;
    final feats = <NodeData>[];
    final rawFeats = features["feats"] as List<dynamic>;

    for (final entry in rawFeats) {
      if (entry is Map) {
        final feat = featureFromJson(Map<String, dynamic>.from(entry));
        if (feat != null) feats.add(feat);
      }
    }

    return FeatureSet(
      id: row["id"] as int,
      title: row["title"] as String,
      values: values,
      status: FeatureSetStatus.fromJson(row["status"]),
      startTimestamp: start,
      endTimestamp: end,
      feats: feats
    );
  }

  Map<String, dynamic> featsToJson() {
    return {
      "feats": feats.map((feat) => feat.toJson()).toList()
    };
  }

  FeatureSet copy() {
    final copiedFeats = feats.map((feat) => feat.copy()).toList();
    return FeatureSet(
      id: id,
      title: title,
      values: values,
      status: status,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      feats: copiedFeats
    );
  }
}
