import 'package:alphchemy/model/json_helpers.dart';

enum OHLC {
  open,
  high,
  low,
  close;

  static OHLC fromJson(String json) {
    switch (json) {
      case 'open': return OHLC.open;
      case 'high': return OHLC.high;
      case 'low': return OHLC.low;
      case 'close': return OHLC.close;
      default: throw ArgumentError('Invalid OHLC: $json');
    }
  }

  String toJson() {
    return name;
  }
}

enum ReturnsType {
  log,
  simple;

  static ReturnsType fromJson(String json) {
    switch (json) {
      case 'log': return ReturnsType.log;
      case 'simple': return ReturnsType.simple;
      default: throw ArgumentError('Invalid ReturnsType: $json');
    }
  }

  String toJson() {
    return name;
  }
}

sealed class Feature {
  const Feature();

  factory Feature.fromJson(Map<String, dynamic> json) {
    final feature = json['feature'] as String;
    switch (feature) {
      case 'constant': return ConstantFeature.fromJson(json);
      case 'raw_returns': return RawReturnsFeature.fromJson(json);
      default: throw ArgumentError('Invalid Feature type: $feature');
    }
  }

  Map<String, dynamic> toJson();
}

Feature featureFromDynamic(dynamic val) {
  final map = val as Map<String, dynamic>;
  return Feature.fromJson(map);
}

class ConstantFeature extends Feature {
  final String id;
  final double constant;

  ConstantFeature({
    required this.id,
    required this.constant
  });

  factory ConstantFeature.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final constant = doubleFromJson(json['constant']);
    return ConstantFeature(id: id, constant: constant);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'feature': 'constant',
      'id': id,
      'constant': constant
    };
  }
}

class RawReturnsFeature extends Feature {
  final String id;
  final ReturnsType returnsType;
  final OHLC ohlc;

  RawReturnsFeature({
    required this.id,
    required this.returnsType,
    required this.ohlc
  });

  factory RawReturnsFeature.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final returnsTypeStr = json['returns_type'] as String;
    final returnsType = ReturnsType.fromJson(returnsTypeStr);
    final ohlcStr = json['ohlc'] as String;
    final ohlc = OHLC.fromJson(ohlcStr);
    return RawReturnsFeature(
      id: id,
      returnsType: returnsType,
      ohlc: ohlc
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'feature': 'raw_returns',
      'id': id,
      'returns_type': returnsType.toJson(),
      'ohlc': ohlc.toJson()
    };
  }
}
