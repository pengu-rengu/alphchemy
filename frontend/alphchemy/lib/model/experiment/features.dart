import "package:alphchemy/model/experiment/node_data.dart";
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

enum MacdOutput {
  line,
  signal,
  histogram;

  static MacdOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "line":
        return MacdOutput.line;
      case "signal":
        return MacdOutput.signal;
      case "histogram":
        return MacdOutput.histogram;
      default:
        throw Exception("Invalid MACD output: $value");
    }
  }

  String toJson() {
    return name;
  }
}

enum BollingerOutput {
  zScore("z_score"),
  bandWidth("band_width");

  final String value;

  const BollingerOutput(this.value);

  static BollingerOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "z_score":
        return BollingerOutput.zScore;
      case "band_width":
        return BollingerOutput.bandWidth;
      default:
        throw Exception("Invalid Bollinger output: $value");
    }
  }

  String toJson() {
    return value;
  }
}

enum StochasticOutput {
  percentK("percent_k"),
  percentD("percent_d");

  final String value;

  const StochasticOutput(this.value);

  static StochasticOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "percent_k":
        return StochasticOutput.percentK;
      case "percent_d":
        return StochasticOutput.percentD;
      default:
        throw Exception("Invalid stochastic output: $value");
    }
  }

  String toJson() {
    return value;
  }
}

enum DonchianOutput {
  position("position"),
  width("width");

  final String value;

  const DonchianOutput(this.value);

  static DonchianOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "position":
        return DonchianOutput.position;
      case "width":
        return DonchianOutput.width;
      default:
        throw Exception("Invalid Donchian output: $value");
    }
  }

  String toJson() {
    return value;
  }
}

int _intFromText(String text, int defaultValue) {
  return int.tryParse(text) ?? defaultValue;
}

double _doubleFromText(String text, double defaultValue) {
  return double.tryParse(text) ?? defaultValue;
}

abstract class OhlcWindowFeature extends NodeData {
  String id;
  OHLC ohlc;
  int window;

  String get featureName;

  @override
  int get fieldCount => 3;

  OhlcWindowFeature({
    this.id = "",
    this.ohlc = OHLC.close,
    this.window = 0
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "window":
        window = _intFromText(text, 0);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "ohlc":
        ohlc = value as OHLC;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "ohlc" => ohlc.name,
      "window" => window.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": featureName,
      "id": id,
      "ohlc": ohlc.toJson(),
      "window": window
    };
  }
}

abstract class WindowFeature extends NodeData {
  String id;
  int window;

  String get featureName;

  @override
  int get fieldCount => 2;

  WindowFeature({
    this.id = "",
    this.window = 0
  });

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "window":
        window = _intFromText(text, 0);
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "window" => window.toString(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": featureName,
      "id": id,
      "window": window
    };
  }
}

class Constant extends NodeData {
  String id;
  double constant;

  @override
  NodeType get nodeType => NodeType.constantFeature;

  @override
  int get fieldCount => 2;

  Constant({this.id = "", this.constant = 0.0});

  factory Constant.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final constant = getField<double>(json, "constant", 0.0, doubleFromJson);

    return Constant(id: id, constant: constant);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "constant":
        constant = _doubleFromText(text, 0.0);
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
    return {
      "feature": "constant",
      "id": id,
      "constant": constant
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
    this.ohlc = OHLC.close
  });

  factory RawReturns.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final returnsType = getField<ReturnsType>(json, "returns_type", ReturnsType.log, ReturnsType.fromJson);
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);

    return RawReturns(id: id, returnsType: returnsType, ohlc: ohlc);
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
    return {
      "feature": "raw_returns",
      "id": id,
      "returns_type": returnsType.toJson(),
      "ohlc": ohlc.toJson()
    };
  }
}

class Sma extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.smaFeature;

  @override
  String get featureName => "sma";

  Sma({super.id, super.ohlc, super.window});

  factory Sma.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return Sma(id: id, ohlc: ohlc, window: window);
  }
}

class Ema extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.emaFeature;

  @override
  String get featureName => "ema";

  Ema({super.id, super.ohlc, super.window});

  factory Ema.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return Ema(id: id, ohlc: ohlc, window: window);
  }
}

class Macd extends NodeData {
  String id;
  OHLC ohlc;
  int fastWindow;
  int slowWindow;
  int signalWindow;
  MacdOutput output;

  @override
  NodeType get nodeType => NodeType.macdFeature;

  @override
  int get fieldCount => 6;

  Macd({
    this.id = "",
    this.ohlc = OHLC.close,
    this.fastWindow = 0,
    this.slowWindow = 0,
    this.signalWindow = 0,
    this.output = MacdOutput.histogram
  });

  factory Macd.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final fastWindow = getField<int>(json, "fast_window", 0);
    final slowWindow = getField<int>(json, "slow_window", 0);
    final signalWindow = getField<int>(json, "signal_window", 0);
    final output = getField<MacdOutput>(json, "output", MacdOutput.histogram, MacdOutput.fromJson);

    return Macd(
      id: id,
      ohlc: ohlc,
      fastWindow: fastWindow,
      slowWindow: slowWindow,
      signalWindow: signalWindow,
      output: output
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "fast_window":
        fastWindow = _intFromText(text, 0);
      case "slow_window":
        slowWindow = _intFromText(text, 0);
      case "signal_window":
        signalWindow = _intFromText(text, 0);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "ohlc":
        ohlc = value as OHLC;
      case "output":
        output = value as MacdOutput;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "ohlc" => ohlc.name,
      "fast_window" => fastWindow.toString(),
      "slow_window" => slowWindow.toString(),
      "signal_window" => signalWindow.toString(),
      "output" => output.toJson(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "macd",
      "id": id,
      "ohlc": ohlc.toJson(),
      "fast_window": fastWindow,
      "slow_window": slowWindow,
      "signal_window": signalWindow,
      "output": output.toJson()
    };
  }
}

class Rsi extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.rsiFeature;

  @override
  String get featureName => "rsi";

  Rsi({super.id, super.ohlc, super.window});

  factory Rsi.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return Rsi(id: id, ohlc: ohlc, window: window);
  }
}

class BollingerBands extends NodeData {
  String id;
  OHLC ohlc;
  int window;
  double stdMult;
  BollingerOutput output;

  @override
  NodeType get nodeType => NodeType.bollingerBandsFeature;

  @override
  int get fieldCount => 5;

  BollingerBands({
    this.id = "",
    this.ohlc = OHLC.close,
    this.window = 0,
    this.stdMult = 2.0,
    this.output = BollingerOutput.zScore
  });

  factory BollingerBands.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);
    final stdMult = getField<double>(json, "std_mult", 2.0, doubleFromJson);
    final output = getField<BollingerOutput>(json, "output", BollingerOutput.zScore, BollingerOutput.fromJson);

    return BollingerBands(
      id: id,
      ohlc: ohlc,
      window: window,
      stdMult: stdMult,
      output: output
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "window":
        window = _intFromText(text, 0);
      case "std_mult":
        stdMult = _doubleFromText(text, 0.0);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "ohlc":
        ohlc = value as OHLC;
      case "output":
        output = value as BollingerOutput;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "ohlc" => ohlc.name,
      "window" => window.toString(),
      "std_mult" => stdMult.toString(),
      "output" => output.toJson(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "bollinger_bands",
      "id": id,
      "ohlc": ohlc.toJson(),
      "window": window,
      "std_mult": stdMult,
      "output": output.toJson()
    };
  }
}

class Stochastic extends NodeData {
  String id;
  int window;
  int smoothWindow;
  StochasticOutput output;

  @override
  NodeType get nodeType => NodeType.stochasticFeature;

  @override
  int get fieldCount => 4;

  Stochastic({
    this.id = "",
    this.window = 0,
    this.smoothWindow = 0,
    this.output = StochasticOutput.percentK
  });

  factory Stochastic.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final window = getField<int>(json, "window", 0);
    final smoothWindow = getField<int>(json, "smooth_window", 0);
    final output = getField<StochasticOutput>(json, "output", StochasticOutput.percentK, StochasticOutput.fromJson);

    return Stochastic(
      id: id,
      window: window,
      smoothWindow: smoothWindow,
      output: output
    );
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "window":
        window = _intFromText(text, 0);
      case "smooth_window":
        smoothWindow = _intFromText(text, 0);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "output":
        output = value as StochasticOutput;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "window" => window.toString(),
      "smooth_window" => smoothWindow.toString(),
      "output" => output.toJson(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "stochastic",
      "id": id,
      "window": window,
      "smooth_window": smoothWindow,
      "output": output.toJson()
    };
  }
}

class Atr extends WindowFeature {
  @override
  NodeType get nodeType => NodeType.atrFeature;

  @override
  String get featureName => "atr";

  Atr({super.id, super.window});

  factory Atr.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final window = getField<int>(json, "window", 0);

    return Atr(id: id, window: window);
  }
}

class Roc extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.rocFeature;

  @override
  String get featureName => "roc";

  Roc({super.id, super.ohlc, super.window});

  factory Roc.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return Roc(id: id, ohlc: ohlc, window: window);
  }
}

class Momentum extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.momentumFeature;

  @override
  String get featureName => "momentum";

  Momentum({super.id, super.ohlc, super.window});

  factory Momentum.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return Momentum(id: id, ohlc: ohlc, window: window);
  }
}

class DonchianChannel extends NodeData {
  String id;
  int window;
  DonchianOutput output;

  @override
  NodeType get nodeType => NodeType.donchianChannelFeature;

  @override
  int get fieldCount => 3;

  DonchianChannel({
    this.id = "",
    this.window = 0,
    this.output = DonchianOutput.position
  });

  factory DonchianChannel.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final window = getField<int>(json, "window", 0);
    final output = getField<DonchianOutput>(json, "output", DonchianOutput.position, DonchianOutput.fromJson);

    return DonchianChannel(id: id, window: window, output: output);
  }

  @override
  void updateField(String fieldKey, String text) {
    switch (fieldKey) {
      case "id":
        id = text;
      case "window":
        window = _intFromText(text, 0);
    }
  }

  @override
  void updateFieldTyped(String fieldKey, dynamic value) {
    switch (fieldKey) {
      case "output":
        output = value as DonchianOutput;
    }
  }

  @override
  String formatField(String fieldKey) {
    return switch (fieldKey) {
      "id" => id,
      "window" => window.toString(),
      "output" => output.toJson(),
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "donchian_channel",
      "id": id,
      "window": window,
      "output": output.toJson()
    };
  }
}

class Cci extends WindowFeature {
  @override
  NodeType get nodeType => NodeType.cciFeature;

  @override
  String get featureName => "cci";

  Cci({super.id, super.window});

  factory Cci.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final window = getField<int>(json, "window", 0);

    return Cci(id: id, window: window);
  }
}
