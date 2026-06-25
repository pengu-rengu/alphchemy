import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/model/notebook/query.dart";

class Notebook {
  final int id;
  String title;
  NotebookStatus status;
  List<Query> queries;
  List<String> notes;

  Notebook({required this.id, required this.title, required this.status, required this.queries, required this.notes});

  factory Notebook.fromJson(Map<String, dynamic> row) {
    final title = row["title"] as String;
    final status = NotebookStatus.fromJson(row["status"]);

    Query parseQuery(dynamic value) => Query.fromJson(value as Map<String, dynamic>);
    final queries = (row["queries"] as List).map(parseQuery).toList();

    final notes = (row["notes"] as List).map((entry) => entry as String).toList();

    return Notebook(
      id: row["id"] as int,
      title: title,
      status: status,
      queries: queries,
      notes: notes
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "status": status.name,
      "queries": queries.map((query) => query.toJson()).toList(),
      "notes": notes
    };
  }

  Notebook copy() => Notebook.fromJson(toJson());
}
