T getField<T>(Map<String, dynamic> json, String key, T defaultValue, [T Function(dynamic value)? fromJson]) {
  final value = json[key];

  if (value == null) {
    return defaultValue;
  }

  if (fromJson != null) {
    return fromJson(value);
  }

  return value as T;
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

String timestampToIso(double seconds) {
  if (seconds <= 0.0) return "";
  final millis = (seconds * 1000.0).round();
  final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  return dt.toIso8601String();
}
