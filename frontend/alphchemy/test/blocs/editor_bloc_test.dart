import "package:alphchemy/blocs/editor_bloc.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("initializes from existing experiment json", () {
    final initialJson = <String, dynamic>{
      "val_size": 0.25,
      "test_size": 0.15,
      "cv_folds": 4,
      "fold_size": 0.5
    };
    final bloc = EditorBloc(initialJson: initialJson);
    addTearDown(bloc.close);

    final json = bloc.exportToJson();

    expect(json["val_size"], 0.25);
    expect(json["test_size"], 0.15);
    expect(json["cv_folds"], 4);
    expect(json["fold_size"], 0.5);
  });
}
