import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment_data.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("experiment data drops legacy title field", () {
    final data = ExperimentData.fromJson({
      "title": "legacy",
      "val_size": 0.2
    });
    final json = data.toJson();

    expect(json.containsKey("title"), false);
    expect(json["val_size"], 0.2);
  });

  test("blank experiment data has no title", () {
    final data = ExperimentData.blank();
    final json = data.toJson();

    expect(json.containsKey("title"), false);
  });

  test("experiment data constructor does not export title", () {
    const data = ExperimentData(experiment: {
      "title": "legacy",
      "val_size": 0.2
    });
    final json = data.toJson();

    expect(json.containsKey("title"), false);
    expect(json["val_size"], 0.2);
  });

  test("experiment model does not export title", () {
    final experiment = Experiment.fromJson({
      "title": "legacy",
      "val_size": 0.2,
      "test_size": 0.1,
      "cv_folds": 4,
      "fold_size": 0.25
    });
    final json = experiment.toJson();

    expect(experiment.fieldCount, 4);
    expect(json.containsKey("title"), false);
    expect(json["val_size"], 0.2);
  });
}
