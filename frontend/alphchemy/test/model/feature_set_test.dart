/*
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/feature_set/feature_set.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("feature set parses known features", () {
    final featureSet = FeatureSet.fromJson(_featureSetRow([
      {
        "feature": "constant",
        "id": "base",
        "constant": 1.5
      }
    ]));

    final feature = featureSet.feats.single as Constant;
    expect(feature.id, "base");
    expect(feature.constant, 1.5);
  });

  test("feature set rejects unknown features", () {
    final row = _featureSetRow([
      {
        "feature": "unknown",
        "id": "future"
      }
    ]);

    expect(() => FeatureSet.fromJson(row), throwsA(isA<Exception>()));
  });

  test("feature set rejects features without feature names", () {
    final row = _featureSetRow([
      {"id": "missing"}
    ]);

    expect(() => FeatureSet.fromJson(row), throwsA(isA<Exception>()));
  });
}

Map<String, dynamic> _featureSetRow(List<Map<String, dynamic>> feats) {
  return {
    "id": 1,
    "title": "Feature Set",
    "status": "idle",
    "start_timestamp": 1.0,
    "end_timestamp": 2.0,
    "features": {"feats": feats}
  };
}
*/

void main() {}
