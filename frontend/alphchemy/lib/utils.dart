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

List<double> toDoubleList(dynamic value) {
  return (value as List).map(doubleFromJson).toList();
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

String formatDate(double seconds) {
  final millis = (seconds * 1000).round();
  final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  final mm = dt.month.toString().padLeft(2, "0");
  final dd = dt.day.toString().padLeft(2, "0");
  final hh = dt.hour.toString().padLeft(2, "0");
  final mi = dt.minute.toString().padLeft(2, "0");
  return "$mm-$dd\n$hh:$mi";
}

String cleanTitle(String title) {
  final trimmed = title.trim();
  return trimmed.isEmpty ? "Untitled" : trimmed;
}
