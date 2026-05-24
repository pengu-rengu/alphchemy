bool isNullable<T>() => null is T;

T getField<T>(Map<String, dynamic> json, String key, {T? defaultValue, T Function(dynamic value)? fromJson}) {
  final value = json[key];

  if (value == null) {
    if (isNullable<T>()) {
      return null as T;
    }

    return switch (T) {
      const(int) => 0 as T,
      const(double) => 0.0 as T,
      const(bool) => false as T,
      const(String) => "" as T,
      const(List<int>) => <int>[] as T,
      const(List<double>) => <double>[] as T,
      const(List<String>) => <String>[] as T,
      Type() => defaultValue!,
    };
  }

  if (fromJson != null) {
    return fromJson(value);
  }

  if (T == double) {
    return doubleFromJson(value) as T;
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

List<double> doubleListFromJson(dynamic value) {
  return (value as List).map(doubleFromJson).toList();
}

String formatDate(double seconds, {bool newLine = true}) {
  final datetime = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true);
  final yyyy = datetime.year.toString().padLeft(4, "0");
  final mm = datetime.month.toString().padLeft(2, "0");
  final dd = datetime.day.toString().padLeft(2, "0");
  final hh = datetime.hour.toString().padLeft(2, "0");
  final mi = datetime.minute.toString().padLeft(2, "0");
  return "$mm-$dd-$yyyy${newLine ? "\n" : " "}$hh:$mi";
}

String cleanTitle(String title) {
  final trimmed = title.trim();
  return trimmed.isEmpty ? "Untitled" : trimmed;
}
