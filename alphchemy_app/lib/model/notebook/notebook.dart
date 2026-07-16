import "package:alphchemy_app/model/notebook/notebook_summary.dart";
import "package:alphchemy_app/model/notebook/query.dart";

class Notebook {
  final int id;
  final String userId;
  String title;
  NotebookStatus status;
  List<Query> queries;
  List<String> notes;

  Notebook({required this.id, required this.userId, required this.title, required this.status, required this.queries, required this.notes});

  factory Notebook.fromJson(Map<String, dynamic> row) {
    final title = row["title"] as String;
    final status = NotebookStatus.fromJson(row["status"]);

    Query parseQuery(dynamic value) => Query.fromJson(value as Map<String, dynamic>);
    final queries = (row["queries"] as List).map(parseQuery).toList();

    final notes = (row["notes"] as List).map((entry) => entry as String).toList();

    return Notebook(
      id: row["id"] as int,
      userId: row["user_id"] as String,
      title: title,
      status: status,
      queries: queries,
      notes: notes
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "title": title,
      "status": status.name,
      "queries": queries.map((query) => query.toJson()).toList(),
      "notes": notes
    };
  }

  Notebook copy() => Notebook.fromJson(toJson());
}
