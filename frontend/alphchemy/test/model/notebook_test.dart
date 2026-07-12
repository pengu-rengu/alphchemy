import "package:alphchemy/model/notebook/notebook.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("notebook parses and preserves its owner", () {
    final notebook = Notebook.fromJson({
      "id": 7,
      "user_id": "user-1",
      "title": "Owned notebook",
      "status": "idle",
      "queries": <Map<String, dynamic>>[],
      "notes": <String>[]
    });

    final copy = notebook.copy();

    expect(notebook.userId, "user-1");
    expect(notebook.status, NotebookStatus.idle);
    expect(copy.userId, "user-1");
    expect(copy.toJson()["user_id"], "user-1");
  });
}
