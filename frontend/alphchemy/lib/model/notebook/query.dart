class QueryResults {
  String path;
  List<dynamic> values;
  int skipped;

  QueryResults({required this.path, required this.values, required this.skipped});

  factory QueryResults.fromJson(Map<String, dynamic> json) {
    return QueryResults(
      path: json["path"] as String,
      values: List<dynamic>.from(json["values"] as List),
      skipped: json["skipped"] as int
    );
  }

  Map<String, dynamic> toJson() {
    return {"path": path, "values": values, "skipped": skipped};
  }
}

class Query {
  String query;
  List<QueryResults>? results;

  Query({required this.query, required this.results});

  factory Query.fromJson(Map<String, dynamic> json) {
    QueryResults parseQueryResults(dynamic value) => QueryResults.fromJson(value as Map<String, dynamic>);
    final results = (json["results"] as List?)?.map(parseQueryResults).toList();

    return Query(
      query: json["query"] as String,
      results: results
    );
  }

  Map<String, dynamic> toJson() {
    return {"query": query, "results": results?.map((result) => result.toJson()).toList()};
  }

  Query copy() => Query.fromJson(toJson());
}
