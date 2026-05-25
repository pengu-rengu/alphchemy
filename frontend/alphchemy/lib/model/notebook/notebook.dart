import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/model/notebook/query.dart";

class NotebookLayout {
  List<String> left;
  List<String> right;

  NotebookLayout({required this.left, required this.right});

  factory NotebookLayout.fromJson(Map<String, dynamic> json) {
    String convertEntry(dynamic entry) => entry as String;

    final left = (json["left"] as List).map(convertEntry).toList();
    final right = (json["right"] as List).map(convertEntry).toList();

    return NotebookLayout(left: left, right: right);
  }

  Map<String, dynamic> toJson() {
    return {"left": left, "right": right};
  }

  NotebookLayout copy() {
    return NotebookLayout.fromJson(toJson());
  }
}

class Notebook {
  final int id;
  String title;
  NotebookStatus status;
  List<Query> queries;
  Map<String, String> notes;
  NotebookLayout layout;

  Notebook({required this.id, required this.title, required this.status, required this.queries, required this.notes, required this.layout});

  factory Notebook.fromJson(Map<String, dynamic> row) {
    final title = row["title"] as String;
    final status = NotebookStatus.fromJson(row["status"]);

    Query parseQuery(dynamic value) => Query.fromJson(value as Map<String, dynamic>);
    final queries = (row["queries"] as List).map(parseQuery).toList();

    final notes = <String, String>{};
    for (final entry in (row["notes"] as Map<String, dynamic>).entries) {
      notes[entry.key] = entry.value as String;
    }
    final layout = NotebookLayout.fromJson(row["layout"] as Map<String, dynamic>);

    return Notebook(
      id: row["id"] as int,
      title: title,
      status: status,
      queries: queries,
      notes: notes,
      layout: layout
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "status": status.name,
      "queries": queries.map((query) => query.toJson()).toList(),
      "notes": notes,
      "layout": layout.toJson()
    };
  }

  Notebook copy() => Notebook.fromJson(toJson());
}
