enum ParamType { intType, floatType, stringType, boolType, intListType }

class Param {
  String name;
  ParamType type;
  List<dynamic> values;

  Param({required this.name, required this.type, required this.values});

  Map<String, dynamic> toJson() {
    return {"search_space_entry": values};
  }
}

ParamType inferParamType(List<dynamic> values) {
  if (values.isEmpty) return ParamType.stringType;
  final first = values.first;
  if (first is bool) return ParamType.boolType;
  if (first is int) return ParamType.intType;
  if (first is double) return ParamType.floatType;
  if (first is String) return ParamType.stringType;
  if (first is List) return ParamType.intListType;
  return ParamType.stringType;
}
