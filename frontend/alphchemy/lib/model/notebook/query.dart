import "package:alphchemy/model/notebook/filter.dart";
import "package:alphchemy/utils.dart";

class QueryResults {
  double min;
  double q1;
  double median;
  double q3;
  double max;

  QueryResults({required this.min, required this.q1, required this.median, required this.q3, required this.max});

  factory QueryResults.fromJson(Map<String, dynamic> json) {
    final min = doubleFromJson(json["min"]);
    final q1 = doubleFromJson(json["q1"]);
    final median = doubleFromJson(json["median"]);
    final q3 = doubleFromJson(json["q3"]);
    final max = doubleFromJson(json["max"]);

    return QueryResults(
      min: min,
      q1: q1,
      median: median,
      q3: q3,
      max: max
    );
  }

  Map<String, dynamic> toJson() {
    return {"min": min, "q1": q1, "median": median, "q3": q3, "max": max};
  }

  QueryResults copy() {
    return QueryResults.fromJson(toJson());
  }

  static QueryResults? parse(dynamic entry) {
    if (entry == null) return null;
    final map = Map<String, dynamic>.from(entry as Map);
    return QueryResults.fromJson(map);
  }
}

class Query {
  List<String> select;
  List<NotebookFilter> filters;
  List<QueryResults?>? results;

  Query({required this.select, required this.filters, required this.results});

  factory Query.fromJson(Map<String, dynamic> json) {

    // TODO: refactor json parsing
    final selectField = (json["select"] as List).map((entry) => entry as String).toList();
    final filtersField = (json["filters"] as List).map((entry) => NotebookFilter.fromJson(Map<String, dynamic>.from(entry as Map))).toList();
    final resultsField = json["results"];
    final results = resultsField is List ? resultsField.map(QueryResults.parse).toList() : null;

    return Query(
      select: selectField,
      filters: filtersField,
      results: results
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "select": select,
      "filters": filters.map((filter) => filter.toJson()).toList(),
      "results": results?.map((entry) => entry?.toJson()).toList()
    };
  }

  Query copy() => Query.fromJson(toJson());
}
