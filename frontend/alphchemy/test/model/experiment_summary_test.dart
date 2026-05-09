import "package:alphchemy/model/experiment_summary.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("parses int ids, title, created date, and status", () {
    final json = {
      "id": 123,
      "created_at": "2026-05-09T12:00:00Z",
      "title": "Momentum test",
      "status": "completed"
    };

    final summary = ExperimentSummary.fromJson(json);

    expect(summary.id, 123);
    expect(summary.title, "Momentum test");
    expect(summary.status, ExperimentStatus.completed);
    expect(summary.status.isCompleted, true);
    expect(summary.createdAt.toUtc().year, 2026);
    expect(summary.toJson()["id"], 123);
  });

  test("falls back to queued status and untitled title", () {
    final json = {
      "id": 124,
      "created_at": "2026-05-09T12:00:00Z",
      "title": " ",
      "status": "unknown"
    };

    final summary = ExperimentSummary.fromJson(json);

    expect(summary.title, "Untitled Experiment");
    expect(summary.status, ExperimentStatus.queued);
  });

  test("parses all experiment statuses", () {
    expect(ExperimentStatus.fromJson("queued"), ExperimentStatus.queued);
    expect(ExperimentStatus.fromJson("running"), ExperimentStatus.running);
    expect(ExperimentStatus.fromJson("completed"), ExperimentStatus.completed);
    expect(ExperimentStatus.fromJson("errored"), ExperimentStatus.errored);
  });
}
