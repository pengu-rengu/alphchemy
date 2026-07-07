bool isNullable<T>() => null is T;

T getField<T>(Map<String, dynamic> json, String key, {T Function(dynamic value)? fromJson}) {
  if (!json.containsKey(key)) {
    throw StateError("Missing required JSON key: $key");
  }

  final value = json[key];

  if (value == null) {
    if (isNullable<T>()) {
      return null as T;
    }
    throw StateError("Null value for non-nullable JSON key: $key");
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

const _monthNames = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
];

String formatDate(double seconds, {bool newLine = true}) {
  final datetime = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true);
  final yyyy = datetime.year.toString().padLeft(4, "0");
  final mm = datetime.month.toString().padLeft(2, "0");
  final dd = datetime.day.toString().padLeft(2, "0");
  final hh = datetime.hour.toString().padLeft(2, "0");
  final mi = datetime.minute.toString().padLeft(2, "0");
  return "$mm-$dd-$yyyy${newLine ? "\n" : " "}$hh:$mi";
}

DateTime parseIsoUtc(String value) {
  final endsWithZulu = value.endsWith("Z");
  final offsetPattern = RegExp(r"[+-]\d\d:\d\d$");
  final hasOffset = offsetPattern.hasMatch(value);
  var normalized = value;

  if (!endsWithZulu && !hasOffset) {
    normalized = "${value}Z";
  }

  final parsed = DateTime.parse(normalized);
  return parsed.toUtc();
}

String formatIsoDate(String value) {
  final datetime = parseIsoUtc(value);
  final month = _monthNames[datetime.month - 1];
  final day = datetime.day.toString();
  final year = datetime.year.toString();
  final hour = datetime.hour.toString().padLeft(2, "0");
  final minute = datetime.minute.toString().padLeft(2, "0");
  return "$month $day $year $hour:$minute";
}

String relativeTime(DateTime value) {
  final mins = DateTime.now().difference(value).inMinutes;
  final hrs = (mins / 60).round();
  final days = (hrs / 24).round();

  if (mins < 1) return "now";
  if (mins < 60) return "${mins}m";
  if (hrs < 24) return "${hrs}h";
  return "${days}d";
}

String cleanTitle(String title) {
  final trimmed = title.trim();
  return trimmed.isEmpty ? "Untitled" : trimmed;
}
