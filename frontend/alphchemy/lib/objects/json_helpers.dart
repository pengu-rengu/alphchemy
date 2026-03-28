String? paramKeyFromJson(dynamic val) {
  if (val is! Map) return null;
  return val["key"] as String?;
}

dynamic assembleField(dynamic value, String fieldKey, Map<String, String> paramRefs) {
  final paramName = paramRefs[fieldKey];
  if (paramName != null) return {"key": paramName};
  return value;
}

int intOrDefault(Map<String, dynamic> json, String jsonKey, String fieldKey, int defaultVal, Map<String, String> paramRefs) {
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    paramRefs[fieldKey] = paramKey;
    return defaultVal;
  }
  return json[jsonKey] as int;
}

double doubleOrDefault(Map<String, dynamic> json,
  String jsonKey,
  String fieldKey,
  double defaultVal,
  Map<String, String> paramRefs
) {
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    paramRefs[fieldKey] = paramKey;
    return defaultVal;
  }
  return doubleFromJson(json[jsonKey]);
}

double? nullDoubleOrDefault(
  Map<String, dynamic> json,
  String jsonKey,
  String fieldKey,
  Map<String, String> paramRefs
) {
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    paramRefs[fieldKey] = paramKey;
    return null;
  }
  return nullDoubleFromJson(json[jsonKey]);
}

int? nullIntOrDefault(Map<String, dynamic> json, String jsonKey, String fieldKey, Map<String, String> refs) {
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    refs[fieldKey] = paramKey;
    return null;
  }
  if (json[jsonKey] == null) return null;
  return json[jsonKey] as int;
}

String stringOrDefault(
  Map<String, dynamic> json,
  String jsonKey,
  String fieldKey,
  String defaultVal,
  Map<String, String> refs
) {
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    refs[fieldKey] = paramKey;
    return defaultVal;
  }
  return json[jsonKey] as String;
}

bool boolOrDefault(
  Map<String, dynamic> json,
  String jsonKey,
  String fieldKey,
  bool defaultVal,
  Map<String, String> refs
) {
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    refs[fieldKey] = paramKey;
    return defaultVal;
  }
  return json[jsonKey] as bool;
}

List<int> intListOrDefault(
  Map<String, dynamic> json,
  String jsonKey,
  String fieldKey,
  List<int> defaultVal,
  Map<String, String> refs
) {
  if (json[jsonKey] == null) return defaultVal;
  final paramKey = paramKeyFromJson(json[jsonKey]);
  if (paramKey != null) {
    refs[fieldKey] = paramKey;
    return defaultVal;
  }
  final raw = json[jsonKey] as List<dynamic>;
  return raw.cast<int>();
}

List<T> listFromJson<T>(List<dynamic> jsonList, T Function(dynamic) converter) {
  final mapped = jsonList.map(converter);
  return mapped.toList();
}

double doubleFromJson(dynamic val) {
  final num_ = val as num;
  return num_.toDouble();
}

double? nullDoubleFromJson(dynamic val) {
  if (val == null) return null;
  final num_ = val as num;
  return num_.toDouble();
}

List<int> parseIntList(String val) {
  return val.split(",")
      .map((str) => str.trim())
      .where((str) => str.isNotEmpty)
      .map((str) => int.tryParse(str) ?? 0)
      .toList();
}
