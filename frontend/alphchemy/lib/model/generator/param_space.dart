class ParamSpace {
  final Map<String, Param> searchSpace;

  ParamSpace({required this.searchSpace});

  factory ParamSpace.empty() {
    return ParamSpace(searchSpace: {});
  }

  static ParamType inferParamType(List<dynamic> values) {
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

  factory ParamSpace.fromJson(Map<String, dynamic> json) {

    final searchSpace = json["search_space"] as Map<String, dynamic>?;
    if (searchSpace == null) {
      throw Exception();
    }

    final params = <String, Param>{};
    for (final entry in searchSpace.entries) {
      final values = entry.value as List<dynamic>;
      final type = inferParamType(values);
      
      params[entry.key] = Param(
        type: type,
        values: values
      );
    }

    return ParamSpace(searchSpace: params);
  }

  Map<String, dynamic> toJson() {
    final searchSpaceJson = <String, List<dynamic>>{};
    for (final entry in searchSpace.entries) {
      searchSpaceJson[entry.key] = entry.value.values;
    }

    return {
      "search_space": searchSpaceJson
    };
  }

  Map<String, Param> paramsOfType(ParamType type) {
    final result = <String, Param>{};
    for (final entry in searchSpace.entries) {
      final param = entry.value;

      if (param.type == type) {
        result[entry.key] = param;
      }
    }

    return result;
  }

  void addParam(String name, Param param) {
    searchSpace[name] = param;
  }

  void updateParamValues(String name, String text) {
    final param = searchSpace[name];
    if (param == null) {
      return;
    }

    param.values = parseParamValuesText(text, param.type);
  }

  void updateParamType(String name, ParamType newType) {
    final param = searchSpace[name];
    if (param == null) {
      return;
    }

    param.type = newType;
  }

  void removeParam(String name) {
    searchSpace.remove(name);
  }

  void renameParam(String oldName, String newName) {
    final param = searchSpace[oldName];
    if (param == null) return;

    searchSpace.remove(oldName);
    searchSpace[newName] = param;
  }

  ParamSpace copy() {
    final copiedSearchSpace = <String, Param>{};

    for (final entry in searchSpace.entries) {
      copiedSearchSpace[entry.key] = entry.value.copy();
    }

    return ParamSpace(searchSpace: copiedSearchSpace);
  }
}

typedef ParamTokenParser<T> = T? Function(String value);

enum ParamType {
  intType,
  floatType,
  stringType,
  boolType,
  intListType,
  stringListType;

  bool get isListType {
    return this == ParamType.intListType || this == ParamType.stringListType;
  }
}

class Param {
  ParamType type;
  List<dynamic> values;

  Param({required this.type, required this.values});

  Param copy() {
    final copiedValues = _copyValues(values);
    return Param(type: type, values: copiedValues);
  }
}

List<dynamic> _copyValues(List<dynamic> values) {
  final copiedValues = <dynamic>[];

  for (final value in values) {
    if (value is! List) {
      copiedValues.add(value);
      continue;
    }

    final nestedValues = List<dynamic>.from(value);
    copiedValues.add(_copyValues(nestedValues));
  }

  return copiedValues;
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
      return _parseCommaSeparated<int>(text, int.tryParse);
    case ParamType.floatType:
      return _parseCommaSeparated<double>(text, double.tryParse);
    case ParamType.stringType:
      return _parseCommaSeparated<String>(text, parseStringToken);
    case ParamType.boolType:
      return _parseCommaSeparated<bool>(text, parseBoolToken);
    case ParamType.intListType:
      return _parseSemicolonSeparated<int>(text, int.tryParse);
    case ParamType.stringListType:
      return _parseSemicolonSeparated<String>(text, parseStringToken);
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

List<T> _parseCommaSeparated<T>(String text, ParamTokenParser<T> parseToken) {
  final parsedValues = <T>[];
  final parts = _splitTokens(text, ",");

  for (final part in parts) {
    final parsedValue = parseToken(part);
    if (parsedValue == null) continue;
    parsedValues.add(parsedValue);
  }

  return parsedValues;
}

List<List<T>> _parseSemicolonSeparated<T>(String text, ParamTokenParser<T> parseToken) {
  final parsedGroups = <List<T>>[];
  final rawGroups = text.split(";");

  for (final rawGroup in rawGroups) {
    final parsedGroup = _parseCommaSeparated<T>(rawGroup, parseToken);
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
