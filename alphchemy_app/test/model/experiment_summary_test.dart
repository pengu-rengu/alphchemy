import "package:alphchemy_app/model/experiment_summary.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("experiment summary parses ownership and visibility", () {
    final summary = ExperimentSummary.fromJson({
      "id": 42,
      "last_updated": "2026-07-11T12:00:00Z",
      "title": "Private experiment",
      "status": "queued",
      "user_id": "user-1",
      "is_public": false
    });

    expect(summary.id, 42);
    expect(summary.userId, "user-1");
    expect(summary.isPublic, false);
    expect(summary.status, ExperimentStatus.queued);
  });

  test("experiment summary accepts ownerless public experiments", () {
    final summary = ExperimentSummary.fromJson({
      "id": 43,
      "last_updated": "2026-07-11T12:00:00Z",
      "title": "Legacy public experiment",
      "status": "completed",
      "user_id": null,
      "is_public": true
    });

    expect(summary.userId, null);
    expect(summary.isPublic, true);
  });
}
