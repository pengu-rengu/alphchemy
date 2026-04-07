import "package:alphchemy/model/generator/node_object.dart";

String? paramNameOrNull(dynamic value) {
  if (value is! Map) return null;
  return value["param"] as String?;
}

T getField<T>(Map<String, dynamic> json, String key, T defaultValue, Map<String, String> paramRefs, [T Function(dynamic value)? fromJson]) {
  final value = json[key];
  final paramName = paramNameOrNull(value);
  
  if (paramName != null) {
    paramRefs[key] = paramName;
    return defaultValue;
  }

  if (value == null) {
    return defaultValue;
  }

  if (fromJson != null) {
    return fromJson(value);
  }

  return value as T;
}

dynamic assembleField(dynamic value, String field, NodeObject data) {
  final paramName = data.paramRefs[field];
  if (paramName != null) return {"param": paramName};
  return value;
}

List<T> listFromJson<T>(dynamic value) {
  return (value as List<dynamic>).map((item) => item as T).toList();
}

double doubleFromJson(dynamic value) {
  final num_ = value as num;
  return num_.toDouble();
}

String castStr(dynamic value) {
  return (value as String).toLowerCase().trim();
}