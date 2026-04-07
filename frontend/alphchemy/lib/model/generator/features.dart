import "package:alphchemy/model/generator/graph_convert.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/model/generator/node_object.dart";
import "package:alphchemy/model/generator/node_ports.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

enum OHLC {
  open, high, low, close;

  static OHLC fromJson(dynamic value) {
    switch (castStr(value)) {
      case "open": return OHLC.open;
      case "high": return OHLC.high;
      case "low": return OHLC.low;
      case "close": return OHLC.close;
      default: throw Exception("Invalid OHLC: $value");
    }
  }

  String toJson() {
    return name;
  }
}

enum ReturnsType {
  log, simple;

  static ReturnsType fromJson(dynamic value) {
    switch (castStr(value)) {
      case "log": return ReturnsType.log;
      case "simple": return ReturnsType.simple;
      default: throw Exception("Invalid returns type: $value");
    }
  }

  String toJson() {
    return name;
  }
}

class Constant extends NodeObject {
  String id;
  double constant;

  @override
  NodeType get nodeType => NodeType.constantFeature;

  Constant({this.id = "", this.constant = 0.0, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": id = text;
      case "constant": constant = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {}

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "constant" => constant.toString(),
      _ => ""
    };
  }

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final constant = getField<double>(json, "constant", 0.0, paramRefs, doubleFromJson);

    final data = Constant(id: id, constant: constant, paramRefs: paramRefs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final data = ctx.findNode(nodeId).data as Constant;

    final id = assembleField(data.id, "id", data);
    final constant = assembleField(data.constant, "constant", data);
    
    return {
      "feature": "constant",
      "id": id,
      "constant": constant
    };
  }
}

class RawReturns extends NodeObject {
  String id;
  ReturnsType returnsType;
  OHLC ohlc;

  @override
  NodeType get nodeType => NodeType.rawReturnsFeature;

  RawReturns({this.id = "", this.returnsType = ReturnsType.log, this.ohlc = OHLC.close, super.paramRefs});

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id": id = text;
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "returns_type": returnsType = value as ReturnsType;
      case "ohlc": ohlc = value as OHLC;
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

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final id = getField<String>(json, "id", "", paramRefs);
    final returnsType = getField<ReturnsType>(json, "returns_type", ReturnsType.log, paramRefs, ReturnsType.fromJson);
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, paramRefs, OHLC.fromJson);

    final data = RawReturns(
      id: id,
      returnsType: returnsType,
      ohlc: ohlc,
      paramRefs: paramRefs
    );
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId);
    final data = node.data as RawReturns;

    final id = assembleField(data.id, "id", data);
    final returnsType = assembleField(data.returnsType.toJson(), "returns_type", data);
    final ohlc = assembleField(data.ohlc.toJson(), "ohlc", data);

    return {
      "feature": "raw_returns",
      "id": id,
      "returns_type": returnsType,
      "ohlc": ohlc
    };
  }
}
