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
