import "package:alphchemy/objects/graph_convert.dart";
import "package:alphchemy/objects/json_helpers.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/node_ports.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
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

  ConstantFeature({this.featId = "", this.constant = 0.0});

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final refs = <String, String>{};
    final featId = stringOrDefault(json, "id", "featId", "", refs);
    final constant = doubleOrDefault(json, "constant", "constant", 0.0, refs);
    final data = ConstantFeature(featId: featId, constant: constant);
    data.paramRefs.addAll(refs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as ConstantFeature;
    
    return {
      "feature": "constant",
      "id": assembleField(data.featId, "featId", data.paramRefs),
      "constant": assembleField(data.constant, "constant", data.paramRefs)
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
    this.featId = "",
    this.returnsType = ReturnsType.log,
    this.ohlc = OHLC.close
  });

  static List<Port> ports() {
    return inputPort();
  }

  static String flatten(FlattenContext ctx, Map<String, dynamic> json) {
    final paramRefs = <String, String>{};
    final featId = stringOrDefault(json, "id", "featId", "", paramRefs);
    final returnsTypeStr = stringOrDefault(json, "returns_type", "returnsType", "log", paramRefs);
    final returnsType = ReturnsType.fromJson(returnsTypeStr);
    final ohlcStr = stringOrDefault(json, "ohlc", "ohlc", "close", paramRefs);
    final ohlc = OHLC.fromJson(ohlcStr);
    final data = RawReturnsFeature(
      featId: featId,
      returnsType: returnsType,
      ohlc: ohlc
    );
    data.paramRefs.addAll(paramRefs);
    return ctx.addNode(data);
  }

  static Map<String, dynamic> assemble(AssembleContext ctx, String nodeId) {
    final node = ctx.findNode(nodeId)!;
    final data = node.data as RawReturnsFeature;
    return {
      "feature": "raw_returns",
      "id": assembleField(data.featId, "featId", data.paramRefs),
      "returns_type": assembleField(data.returnsType.toJson(), "returnsType", data.paramRefs),
      "ohlc": assembleField(data.ohlc.toJson(), "ohlc", data.paramRefs)
    };
  }
}

class ConstantFeatureContent extends StatelessWidget {
  final ConstantFeature data;

  const ConstantFeatureContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "featId",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeTextField(
            label: "featId",
            value: data.featId,
            onChanged: (val) => data.featId = val
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "constant",
          paramType: ParamType.floatType,
          nodeData: data,
          child: NodeTextField(
            label: "constant",
            value: data.constant.toString(),
            onChanged: (val) => data.constant = double.tryParse(val) ?? 0
          )
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
        ParamField(
          fieldKey: "featId",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeTextField(
            label: "featId",
            value: data.featId,
            onChanged: (val) => data.featId = val
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "returnsType",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeDropdown<ReturnsType>(
            label: "returns",
            value: data.returnsType,
            options: ReturnsType.values,
            labelFor: (val) => val.name,
            onChanged: (val) => data.returnsType = val
          )
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "ohlc",
          paramType: ParamType.stringType,
          nodeData: data,
          child: NodeDropdown<OHLC>(
            label: "ohlc",
            value: data.ohlc,
            options: OHLC.values,
            labelFor: (val) => val.name,
            onChanged: (val) => data.ohlc = val
          )
        )
      ]
    );
  }
}
