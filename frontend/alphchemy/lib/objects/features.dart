import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/material.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

enum OHLC {
  open, high, low, close;

  static OHLC fromJson(String json) {
    switch (json) {
      case "open": return OHLC.open;
      case "high": return OHLC.high;
      case "low": return OHLC.low;
      case "close": return OHLC.close;
      default: throw ArgumentError("Invalid OHLC: $json");
    }
  }

  String toJson() {
    return name;
  }
}

enum ReturnsType {
  log, simple;

  static ReturnsType fromJson(String json) {
    switch (json) {
      case "log": return ReturnsType.log;
      case "simple": return ReturnsType.simple;
      default: throw ArgumentError("Invalid ReturnsType: $json");
    }
  }

  String toJson() {
    return name;
  }
}

class ConstantFeature extends NodeObject {
  String featId;
  double constant;

  @override
  String get nodeType => "constant_feature";

  ConstantFeature({required this.featId, required this.constant});

  static int get fieldCount => 2;

  static List<Port> ports() {
    return inputPort(0, fieldCount);
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int column) {
    final featId = json["id"] as String;
    final constant = doubleFromJson(json["constant"]);
    final data = ConstantFeature(featId: featId, constant: constant);
    return ctx.addNode(data, column);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ConstantFeature;
    return {
      "feature": "constant",
      "id": data.featId,
      "constant": data.constant
    };
  }
}

class RawReturnsFeature extends NodeObject {
  String featId;
  ReturnsType returnsType;
  OHLC ohlc;

  @override
  String get nodeType => "raw_returns_feature";

  RawReturnsFeature({
    required this.featId,
    required this.returnsType,
    required this.ohlc
  });

  static int get fieldCount => 3;

  static List<Port> ports() {
    return inputPort(0, fieldCount);
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json, int column) {
    final featId = json["id"] as String;
    final returnsTypeStr = json["returns_type"] as String;
    final returnsType = ReturnsType.fromJson(returnsTypeStr);
    final ohlcStr = json["ohlc"] as String;
    final ohlc = OHLC.fromJson(ohlcStr);
    final data = RawReturnsFeature(
      featId: featId,
      returnsType: returnsType,
      ohlc: ohlc
    );
    return ctx.addNode(data, column);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as RawReturnsFeature;
    return {
      "feature": "raw_returns",
      "id": data.featId,
      "returns_type": data.returnsType.toJson(),
      "ohlc": data.ohlc.toJson()
    };
  }
}

String flattenFeature(FlattenContext ctx, Map<String, dynamic> json, int column) {
  final feature = json["feature"] as String;
  if (feature == "constant") {
    return ConstantFeature.flatten(ctx, json, column);
  }
  return RawReturnsFeature.flatten(ctx, json, column);
}

Map<String, dynamic> assembleFeature(AssembleContext ctx, String nodeId) {
  final node = ctx.findNode(nodeId)!;
  if (node.data is ConstantFeature) {
    return ConstantFeature.assemble(ctx, nodeId);
  }
  return RawReturnsFeature.assemble(ctx, nodeId);
}

class ConstantFeatureContent extends StatelessWidget {
  final ConstantFeature data;

  const ConstantFeatureContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "featId",
          value: data.featId,
          onChanged: (val) => data.featId = val
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "constant",
          value: data.constant.toString(),
          onChanged: (val) => data.constant = double.tryParse(val) ?? 0
        )
      ]
    );
  }
}

class RawReturnsFeatureContent extends StatelessWidget {
  final RawReturnsFeature data;

  const RawReturnsFeatureContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "featId",
          value: data.featId,
          onChanged: (val) => data.featId = val
        ),
        SizedBox(height: 2),
        NodeDropdown<ReturnsType>(
          label: "returns",
          value: data.returnsType,
          options: ReturnsType.values,
          labelFor: (val) => val.name,
          onChanged: (val) => data.returnsType = val
        ),
        SizedBox(height: 2),
        NodeDropdown<OHLC>(
          label: "ohlc",
          value: data.ohlc,
          options: OHLC.values,
          labelFor: (val) => val.name,
          onChanged: (val) => data.ohlc = val
        )
      ]
    );
  }
}
