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

}

enum MACDOutput {
  line,
  signal,
  hist;

  static MACDOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "line":
        return MACDOutput.line;
      case "signal":
        return MACDOutput.signal;
      case "hist":
        return MACDOutput.hist;
      default:
        throw Exception("Invalid MACD output: $value");
    }
  }

}

enum BBOutput {
  upper,
  lower,
  width;

  static BBOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "upper":
        return BBOutput.upper;
      case "lower":
        return BBOutput.lower;
      case "width":
        return BBOutput.width;
      default:
        throw Exception("Invalid Bollinger output: $value");
    }
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
  upper,
  lower,
  middle,
  width;

  static DonchianOutput fromJson(dynamic value) {
    switch (castStr(value)) {
      case "upper":
        return DonchianOutput.upper;
      case "lower":
        return DonchianOutput.lower;
      case "middle":
        return DonchianOutput.middle;
      case "width":
        return DonchianOutput.width;
      default:
        throw Exception("Invalid Donchian output: $value");
    }
  }
}

abstract class OhlcWindowFeature extends NodeData {
  String id;
  OHLC ohlc;
  int window;

  String get featureName;

  @override
  int get fieldCount => 3;

  OhlcWindowFeature({this.id = "", this.ohlc = OHLC.close, this.window = 0});

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "window":
        window = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "ohlc":
        ohlc = value as OHLC;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
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
      "ohlc": ohlc.name,
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
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "window":
        window = int.tryParse(text) ?? 0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
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
  NodeType get nodeType => NodeType.constant;

  @override
  int get fieldCount => 2;

  Constant({this.id = "", this.constant = 0.0});

  factory Constant.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final constant = getField<double>(json, "constant", 0.0, doubleFromJson);

    return Constant(id: id, constant: constant);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "constant":
        constant = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
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
  NodeType get nodeType => NodeType.rawReturns;

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
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "returns_type":
        returnsType = value as ReturnsType;
      case "ohlc":
        ohlc = value as OHLC;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
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
      "returns_type": returnsType.name,
      "ohlc": ohlc.name
    };
  }
}

class NormalizedSMA extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.normalizedSma;

  @override
  String get featureName => "normalized_sma";

  NormalizedSMA({super.id, super.ohlc, super.window});

  factory NormalizedSMA.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return NormalizedSMA(id: id, ohlc: ohlc, window: window);
  }
}

class NormalizedEMA extends OhlcWindowFeature {
  int smooth;

  @override
  NodeType get nodeType => NodeType.normalizedEma;

  @override
  String get featureName => "normalized_ema";

  @override
  int get fieldCount => super.fieldCount + 1;

  NormalizedEMA({super.id, super.ohlc, super.window, this.smooth = 0});

  factory NormalizedEMA.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);
    final smooth = getField<int>(json, "smooth", 0);

    return NormalizedEMA(id: id, ohlc: ohlc, window: window, smooth: smooth);
  }

  @override
  void updateField(String field, String text) {
    if (field == "smooth") {
      smooth = int.tryParse(text) ?? 0;
      return;
    }

    super.updateField(field, text);
  }

  @override
  String formatField(String field) {
    if (field == "smooth") {
      return smooth.toString();
    }

    return super.formatField(field);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json["smooth"] = smooth;
    return json;
  }
}

class NormalizedMACD extends NodeData {
  String id;
  OHLC ohlc;
  int fastWindow;
  int slowWindow;
  int signalWindow;
  int fastSmooth;
  int slowSmooth;
  int signalSmooth;
  MACDOutput output;

  @override
  NodeType get nodeType => NodeType.normalizedMacd;

  @override
  int get fieldCount => 9;

  NormalizedMACD({this.id = "", this.ohlc = OHLC.close, this.fastWindow = 0, this.slowWindow = 0, this.signalWindow = 0, this.fastSmooth = 0, this.slowSmooth = 0, this.signalSmooth = 0, this.output = MACDOutput.line});

  factory NormalizedMACD.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final fastWindow = getField<int>(json, "fast_window", 0);
    final slowWindow = getField<int>(json, "slow_window", 0);
    final signalWindow = getField<int>(json, "signal_window", 0);
    final fastSmooth = getField<int>(json, "fast_smooth", 0);
    final slowSmooth = getField<int>(json, "slow_smooth", 0);
    final signalSmooth = getField<int>(json, "signal_smooth", 0);
    final output = getField<MACDOutput>(json, "output", MACDOutput.line, MACDOutput.fromJson);

    return NormalizedMACD(
      id: id,
      ohlc: ohlc,
      fastWindow: fastWindow,
      slowWindow: slowWindow,
      signalWindow: signalWindow,
      fastSmooth: fastSmooth,
      slowSmooth: slowSmooth,
      signalSmooth: signalSmooth,
      output: output
    );
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "fast_window":
        fastWindow = int.tryParse(text) ?? 0;
      case "slow_window":
        slowWindow = int.tryParse(text) ?? 0;
      case "signal_window":
        signalWindow = int.tryParse(text) ?? 0;
      case "fast_smooth":
        fastSmooth = int.tryParse(text) ?? 0;
      case "slow_smooth":
        slowSmooth = int.tryParse(text) ?? 0;
      case "signal_smooth":
        signalSmooth = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "ohlc":
        ohlc = value as OHLC;
      case "output":
        output = value as MACDOutput;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "id" => id,
      "ohlc" => ohlc.name,
      "fast_window" => fastWindow.toString(),
      "slow_window" => slowWindow.toString(),
      "signal_window" => signalWindow.toString(),
      "fast_smooth" => fastSmooth.toString(),
      "slow_smooth" => slowSmooth.toString(),
      "signal_smooth" => signalSmooth.toString(),
      "output" => output.name,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "normalized_macd",
      "id": id,
      "ohlc": ohlc.name,
      "fast_window": fastWindow,
      "slow_window": slowWindow,
      "signal_window": signalWindow,
      "fast_smooth": fastSmooth,
      "slow_smooth": slowSmooth,
      "signal_smooth": signalSmooth,
      "output": output.name
    };
  }
}

class RSI extends OhlcWindowFeature {
  int smooth;

  @override
  NodeType get nodeType => NodeType.rsi;

  @override
  String get featureName => "rsi";

  @override
  int get fieldCount => super.fieldCount + 1;

  RSI({super.id, super.ohlc, super.window, this.smooth = 0});

  factory RSI.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);
    final smooth = getField<int>(json, "smooth", 0);

    return RSI(id: id, ohlc: ohlc, window: window, smooth: smooth);
  }

  @override
  void updateField(String field, String text) {
    if (field == "smooth") {
      smooth = int.tryParse(text) ?? 0;
      return;
    }

    super.updateField(field, text);
  }

  @override
  String formatField(String field) {
    if (field == "smooth") {
      return smooth.toString();
    }

    return super.formatField(field);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json["smooth"] = smooth;
    return json;
  }
}

class NormalizedBB extends NodeData {
  String id;
  OHLC ohlc;
  int window;
  double stdMultiplier;
  BBOutput output;

  @override
  NodeType get nodeType => NodeType.normalizedBb;

  @override
  int get fieldCount => 5;

  NormalizedBB({this.id = "", this.ohlc = OHLC.close, this.window = 0, this.stdMultiplier = 0.0, this.output = BBOutput.upper});

  factory NormalizedBB.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);
    final stdMult = getField<double>(json, "std_multiplier", 0.0, doubleFromJson);
    final output = getField<BBOutput>(json, "output", BBOutput.upper, BBOutput.fromJson);

    return NormalizedBB(
      id: id,
      ohlc: ohlc,
      window: window,
      stdMultiplier: stdMult,
      output: output
    );
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "window":
        window = int.tryParse(text) ?? 0;
      case "std_multiplier":
        stdMultiplier = double.tryParse(text) ?? 0.0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "ohlc":
        ohlc = value as OHLC;
      case "output":
        output = value as BBOutput;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "id" => id,
      "ohlc" => ohlc.name,
      "window" => window.toString(),
      "std_multiplier" => stdMultiplier.toString(),
      "output" => output.name,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "normalized_bb",
      "id": id,
      "ohlc": ohlc.name,
      "window": window,
      "std_multiplier": stdMultiplier,
      "output": output.name
    };
  }
}

class Stochastic extends NodeData {
  String id;
  int window;
  int smoothWindow;
  StochasticOutput output;

  @override
  NodeType get nodeType => NodeType.stochastic;

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

    return Stochastic(id: id, window: window, smoothWindow: smoothWindow, output: output);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "window":
        window = int.tryParse(text) ?? 0;
      case "smooth_window":
        smoothWindow = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "output":
        output = value as StochasticOutput;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
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

class NormalizedATR extends WindowFeature {
  int smooth;

  @override
  NodeType get nodeType => NodeType.atr;

  @override
  String get featureName => "normalized_atr";

  @override
  int get fieldCount => super.fieldCount + 1;

  NormalizedATR({super.id, super.window, this.smooth = 0});

  factory NormalizedATR.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final window = getField<int>(json, "window", 0);
    final smooth = getField<int>(json, "smooth", 0);

    return NormalizedATR(id: id, window: window, smooth: smooth);
  }

  @override
  void updateField(String field, String text) {
    if (field == "smooth") {
      smooth = int.tryParse(text) ?? 0;
      return;
    }

    super.updateField(field, text);
  }

  @override
  String formatField(String field) {
    if (field == "smooth") {
      return smooth.toString();
    }

    return super.formatField(field);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json["smooth"] = smooth;
    return json;
  }
}

class ROC extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.roc;

  @override
  String get featureName => "roc";

  ROC({super.id, super.ohlc, super.window});

  factory ROC.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final ohlc = getField<OHLC>(json, "ohlc", OHLC.close, OHLC.fromJson);
    final window = getField<int>(json, "window", 0);

    return ROC(id: id, ohlc: ohlc, window: window);
  }
}

class NormalizedDC extends NodeData {
  String id;
  int window;
  DonchianOutput output;

  @override
  NodeType get nodeType => NodeType.normalizedDc;

  @override
  int get fieldCount => 3;

  NormalizedDC({
    this.id = "",
    this.window = 0,
    this.output = DonchianOutput.upper
  });

  factory NormalizedDC.fromJson(Map<String, dynamic> json) {
    final id = getField<String>(json, "id", "");
    final window = getField<int>(json, "window", 0);
    final output = getField<DonchianOutput>(json, "output", DonchianOutput.upper, DonchianOutput.fromJson);

    return NormalizedDC(id: id, window: window, output: output);
  }

  @override
  void updateField(String field, String text) {
    switch (field) {
      case "id":
        id = text;
      case "window":
        window = int.tryParse(text) ?? 0;
    }
  }

  @override
  void updateFieldTyped(String field, dynamic value) {
    switch (field) {
      case "output":
        output = value as DonchianOutput;
    }
  }

  @override
  String formatField(String field) {
    return switch (field) {
      "id" => id,
      "window" => window.toString(),
      "output" => output.name,
      _ => ""
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "feature": "normalized_dc",
      "id": id,
      "window": window,
      "output": output.name
    };
  }
}
