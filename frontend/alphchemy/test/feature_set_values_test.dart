import "package:alphchemy/model/feature_set/feature_set.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses errored feature set values", () {
    final featureSet = FeatureSet.fromJson({
      "id": 1,
      "title": "Broken",
      "features": {
        "feats": []
      },
      "start_timestamp": 0,
      "end_timestamp": 0,
      "values": {
        "error": "boom"
      },
      "status": "errored"
    });

    expect(featureSet.values?.error, "boom");
    expect(featureSet.values?.ohlc, isNull);
    expect(featureSet.values?.featTable, isEmpty);
  });
}
