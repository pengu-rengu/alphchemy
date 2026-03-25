import 'package:alphchemy/model/node_object.dart';

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

class ConstantFeature extends NodeObject {
  String featId;
  double constant;

  @override
  String get nodeType => 'constant_feature';

  ConstantFeature({
    required this.featId,
    required this.constant
  });
}

class RawReturnsFeature extends NodeObject {
  String featId;
  ReturnsType returnsType;
  OHLC ohlc;

  @override
  String get nodeType => 'raw_returns_feature';

  RawReturnsFeature({
    required this.featId,
    required this.returnsType,
    required this.ohlc
  });
}
