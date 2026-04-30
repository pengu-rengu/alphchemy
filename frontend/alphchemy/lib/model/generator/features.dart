import "package:alphchemy/model/generator/node_data.dart";
import "package:alphchemy/utils.dart";

enum OHLC {
  open,
  high,
  low,
  close;

  static OHLC fromJson(dynamic value) {
    switch (castStr(value)) {
      case "open":
        return OHLC.open;
      case "high":
        return OHLC.high;
      case "low":
        return OHLC.low;
      case "close":
        return OHLC.close;
      default:
        throw Exception("Invalid OHLC: $value");
    }
  }

  String toJson() {
    return name;
  }
}

enum ReturnsType {
  log,
  simple;

  static ReturnsType fromJson(dynamic value) {
    switch (castStr(value)) {
      case "log":
        return ReturnsType.log;
      case "simple":
        return ReturnsType.simple;
      default:
        throw Exception("Invalid returns type: $value");
    }
  }

  String toJson() {
    return name;
  }
}

class Constant extends NodeData {
  String id;
  double constant;

  @override
  NodeType get nodeType => NodeType.constantFeature;

  @override
  int get fieldCount => 2;

  Constant({this.id = "", this.constant = 0.0, super.paramRefs});

  factory Constant.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final constant = getField<double>(json, "constant", 0.0, paramRefs, doubleFromJson);

    return Constant(id: id, constant: constant, paramRefs: paramRefs);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "constant":
        constant = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "constant" => constant.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final constantJson = assembleField("constant", constant);

    return {
      "feature": "constant",
      "id": idJson,
      "constant": constantJson
    };
  }
}

class RawReturns extends NodeData {
  String id;
  ReturnsType returnsType;
  OHLC ohlc;

  @override
  NodeType get nodeType => NodeType.rawReturnsFeature;

  @override
  int get fieldCount => 3;

  RawReturns({
    this.id = "",
    this.returnsType = ReturnsType.log,
    this.ohlc = OHLC.close,
    super.paramRefs
  });

  factory RawReturns.fromJson(Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final returnsType = getField<ReturnsType>(json, "returns_type", ReturnsType.log, paramRefs, ReturnsType.fromJson);
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, paramRefs, OHLC.fromJson);

    return RawReturns(
      id: id,
      returnsType: returnsType,
      ohlc: ohlc,
      paramRefs: paramRefs
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "returns_type":
        returnsType = value as ReturnsType;
      case "ohlc":
        ohlc = value as OHLC;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "returns_type" => returnsType.name,
      "ohlc" => ohlc.name,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final idJson = assembleField("id", id);
    final returnsTypeJson = assembleField("returns_type", returnsType.toJson());
    final ohlcJson = assembleField("ohlc", ohlc.toJson());

    return {
      "feature": "raw_returns",
      "id": idJson,
      "returns_type": returnsTypeJson,
      "ohlc": ohlcJson
    };
  }
}
