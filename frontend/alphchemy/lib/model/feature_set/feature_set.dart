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

NodeData featureFromJson(Map<String, dynamic> json) {
  final feature = json["feature"];

  return switch (feature) {
    "constant" => Constant.fromJson(json),
    "raw_returns" => RawReturns.fromJson(json),
    "normalized_sma" => NormalizedSMA.fromJson(json),
    "normalized_ema" => NormalizedEMA.fromJson(json),
    "normalized_macd" => NormalizedMACD.fromJson(json),
    "rsi" => RSI.fromJson(json),
    "normalized_bb" => NormalizedBB.fromJson(json),
    "stochastic" => Stochastic.fromJson(json),
    "normalized_atr" => NormalizedATR.fromJson(json),
    "roc" => ROC.fromJson(json),
    "normalized_dc" => NormalizedDC.fromJson(json),
    _ => throw Exception("Invalid feature: $feature")
  };
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
    final features = row["features"] as Map<String, dynamic>;
    final start = getField<double>(row, "start_timestamp");
    final end = getField<double>(row, "end_timestamp");
    final valuesField = row["values"] as Map<String, dynamic>?;
    final values = valuesField == null ? null : FeatureSetValues.fromJson(valuesField);
    final feats = <NodeData>[];

    for (final entry in features["feats"] as List<dynamic>) {
      final feat = featureFromJson(entry as Map<String, dynamic>);
      feats.add(feat);
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
