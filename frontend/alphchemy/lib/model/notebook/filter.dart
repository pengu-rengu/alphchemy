sealed class NotebookFilter {
  String path;

  NotebookFilter({required this.path});

  String get type;

  Map<String, dynamic> toJson();

  NotebookFilter copy();

  static NotebookFilter fromJson(Map<String, dynamic> json) {
    final type = json["type"] as String;

    return switch (type) {
      "numeric" => NumericFilter.fromJson(json),
      "string" => StringFilter.fromJson(json),
      "bool" => BoolFilter.fromJson(json),
      _ => throw StateError("unknown filter type: $type")
    };
  }
}

class NumericFilter extends NotebookFilter {
  double? gte;
  double? lte;
  double? eq;

  NumericFilter({required super.path, this.gte, this.lte, this.eq});

  static double? _doubleOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    return (value as num).toDouble();
  }

  factory NumericFilter.fromJson(Map<String, dynamic> json) {
    final gte = _doubleOrNull(json["gte"]);
    final lte = _doubleOrNull(json["lte"]);
    final eq = _doubleOrNull(json["eq"]);

    return NumericFilter(
      path: json["path"] as String,
      gte: gte,
      lte: lte,
      eq: eq
    );
  }

  @override
  String get type => "numeric";

  @override
  Map<String, dynamic> toJson() {
    return {"type": type, "path": path, "gte": gte, "lte": lte, "eq": eq};
  }

  @override
  NumericFilter copy() {
    return NumericFilter.fromJson(toJson());
  }
}

class StringFilter extends NotebookFilter {
  String eq;

  StringFilter({required super.path, required this.eq});

  factory StringFilter.fromJson(Map<String, dynamic> json) {
    final value = json["eq"] as String;

    return StringFilter(
      path: json["path"] as String,
      eq: value
    );
  }

  @override
  String get type => "string";

  @override
  Map<String, dynamic> toJson() {
    return {"type": type, "path": path, "eq": eq};
  }

  @override
  StringFilter copy() {
    return StringFilter.fromJson(toJson());
  }
}

class BoolFilter extends NotebookFilter {
  bool eq;

  BoolFilter({required super.path, required this.eq});

  factory BoolFilter.fromJson(Map<String, dynamic> json) {
    final value = json["eq"] as bool;

    return BoolFilter(
      path: json["path"] as String,
      eq: value
    );
  }

  @override
  String get type => "bool";

  @override
  Map<String, dynamic> toJson() {
    return {"type": type, "path": path, "eq": eq};
  }

  @override
  BoolFilter copy() {
    return BoolFilter.fromJson(toJson());
  }
}
