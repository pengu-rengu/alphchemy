typedef ParamTokenParser<T> = T? Function(String value);

enum ParamType {
  intType,
  floatType,
  stringType,
  boolType,
  intListType,
  stringListType
}

class Param {
  String name;
  ParamType type;
  List<dynamic> values;

  Param({required this.name, required this.type, required this.values});
}

extension ParamTypeExt on ParamType {
  bool get isListType {
    return this == ParamType.intListType || this == ParamType.stringListType;
  }
}

ParamType inferParamType(List<dynamic> values) {
  if (values.isEmpty) {
    return ParamType.stringType;
  }

  final nestedType = inferNestedListType(values);
  if (nestedType != null) return nestedType;

  final firstValue = values.first;
  if (firstValue is bool) return ParamType.boolType;
  if (firstValue is int) return ParamType.intType;
  if (firstValue is double) return ParamType.floatType;
  if (firstValue is String) return ParamType.stringType;

  return ParamType.stringType;
}

ParamType? inferNestedListType(List<dynamic> values) {
  var hasNestedValues = false;

  for (final value in values) {
    if (value is! List) continue;
    hasNestedValues = true;
    if (value.isEmpty) continue;

    final firstItem = value.first;
    if (firstItem is int) {
      return ParamType.intListType;
    }
  }

  if (hasNestedValues) return ParamType.stringListType;
  return null;
}

String formatParamValuesText(List<dynamic> values, ParamType type) {
  if (type.isListType) {
    return _formatListValuesText(values);
  }
  return _formatScalarValuesText(values);
}

List<dynamic> parseParamValuesText(String text, ParamType type) {
  switch (type) {
    case ParamType.intType:
      return _parseCommaSeparatedValues<int>(text, int.tryParse);
    case ParamType.floatType:
      return _parseCommaSeparatedValues<double>(text, double.tryParse);
    case ParamType.stringType:
      return _parseCommaSeparatedValues<String>(text, parseStringToken);
    case ParamType.boolType:
      return _parseCommaSeparatedValues<bool>(text, parseBoolToken);
    case ParamType.intListType:
      return _parseSemicolonSeparatedValues<int>(text, int.tryParse);
    case ParamType.stringListType:
      return _parseSemicolonSeparatedValues<String>(text, parseStringToken);
  }
}

bool? parseBoolToken(String value) {
  final normalized = value.toLowerCase();
  if (normalized == "true") return true;
  if (normalized == "false") return false;
  return null;
}

String? parseStringToken(String value) {
  if (value.isEmpty) return null;
  return value;
}

String _formatScalarValuesText(List<dynamic> values) {
  final formatted = <String>[];

  for (final value in values) {
    formatted.add(value.toString());
  }

  return formatted.join(", ");
}

String _formatListValuesText(List<dynamic> values) {
  final formattedGroups = <String>[];
  var hasNestedValues = false;

  for (final value in values) {
    if (value is! List) continue;
    hasNestedValues = true;

    final formattedGroup = _formatScalarValuesText(value);
    if (formattedGroup.isEmpty) continue;
    formattedGroups.add(formattedGroup);
  }

  if (hasNestedValues) {
    return formattedGroups.join("; ");
  }

  return _formatScalarValuesText(values);
}

List<T> _parseCommaSeparatedValues<T>(
  String text,
  ParamTokenParser<T> parseToken
) {
  final parsedValues = <T>[];
  final parts = _splitTokens(text, ",");

  for (final part in parts) {
    final parsedValue = parseToken(part);
    if (parsedValue == null) continue;
    parsedValues.add(parsedValue);
  }

  return parsedValues;
}

List<List<T>> _parseSemicolonSeparatedValues<T>(String text, ParamTokenParser<T> parseToken) {
  final parsedGroups = <List<T>>[];
  final rawGroups = text.split(";");

  for (final rawGroup in rawGroups) {
    final parsedGroup = _parseCommaSeparatedValues<T>(rawGroup, parseToken);
    if (parsedGroup.isEmpty) continue;
    parsedGroups.add(parsedGroup);
  }

  return parsedGroups;
}

List<String> _splitTokens(String text, String delimiter) {
  final parts = text.split(delimiter);
  final tokens = <String>[];

  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    tokens.add(trimmed);
  }

  return tokens;
}
