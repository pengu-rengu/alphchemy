import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

class OhlcDropdown extends StatelessWidget {
  const OhlcDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return const NodeDropdown<OHLC>(
      label: "ohlc",
      field: "ohlc",
      options: OHLC.values,
      optionLabel: OhlcDropdown._label
    );
  }

  static String _label(OHLC value) {
    return value.name;
  }
}

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

mixin FeatureChartInfo {
  String get id;
  String get featureName;
  String get outputName => "";
  bool get isBarChart => false;
  Map<double, String> get chartRefLines => {};
}

abstract class OhlcWindowFeature extends NodeData with FeatureChartInfo {
  @override
  String id;
  OHLC ohlc;
  int window;

  @override
  String get featureName;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    OhlcDropdown(),
    NodeTextField(label: "Window", field: "window")
  ];

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
      "node_id": nodeId,
      "feature": featureName,
      "id": id,
      "ohlc": ohlc.name,
      "window": window
    };
  }
}

abstract class WindowFeature extends NodeData with FeatureChartInfo {
  @override
  String id;
  int window;

  @override
  String get featureName;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    NodeTextField(label: "Window", field: "window")
  ];

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
      "node_id": nodeId,
      "feature": featureName,
      "id": id,
      "window": window
    };
  }
}

class Constant extends NodeData with FeatureChartInfo {
  @override
  String id;
  double constant;

  @override
  NodeType get nodeType => NodeType.constant;

  @override
  String get featureName => "constant";

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    NodeTextField(label: "Constant", field: "constant")
  ];

  Constant({this.id = "", this.constant = 0.0});

  factory Constant.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final constant = getField<double>(json, "constant");

    final node = Constant(id: id, constant: constant);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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
      "node_id": nodeId,
      "feature": "constant",
      "id": id,
      "constant": constant
    };
  }

  @override
  NodeData copy() {
    return Constant.fromJson(toJson());
  }
}

class RawReturns extends NodeData with FeatureChartInfo {
  @override
  String id;
  ReturnsType returnsType;
  OHLC ohlc;

  @override
  NodeType get nodeType => NodeType.rawReturns;

  @override
  String get featureName => "raw_returns";

  @override
  bool get isBarChart => true;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    NodeDropdown<ReturnsType>(
      label: "returns",
      field: "returns_type",
      options: ReturnsType.values,
      optionLabel: RawReturns._returnsLabel
    ),
    OhlcDropdown()
  ];

  RawReturns({
    this.id = "",
    this.returnsType = ReturnsType.log,
    this.ohlc = OHLC.close
  });

  static String _returnsLabel(ReturnsType value) {
    return value.name;
  }

  factory RawReturns.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final returnsType = getField<ReturnsType>(json, "returns_type", defaultValue: ReturnsType.log, fromJson: ReturnsType.fromJson);
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);

    final node = RawReturns(id: id, returnsType: returnsType, ohlc: ohlc);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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
      "node_id": nodeId,
      "feature": "raw_returns",
      "id": id,
      "returns_type": returnsType.name,
      "ohlc": ohlc.name
    };
  }

  @override
  NodeData copy() {
    return RawReturns.fromJson(toJson());
  }
}

class NormalizedSMA extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.normalizedSma;

  @override
  String get featureName => "normalized_sma";

  @override
  Map<double, String> get chartRefLines => {1.0: "1.00"};

  NormalizedSMA({super.id, super.ohlc, super.window});

  factory NormalizedSMA.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);
    final window = getField<int>(json, "window");

    final node = NormalizedSMA(id: id, ohlc: ohlc, window: window);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  NodeData copy() {
    return NormalizedSMA.fromJson(toJson());
  }
}

class NormalizedEMA extends OhlcWindowFeature {
  int smooth;

  @override
  NodeType get nodeType => NodeType.normalizedEma;

  @override
  String get featureName => "normalized_ema";

  @override
  Map<double, String> get chartRefLines => {1.0: "1.00"};

  @override
  List<Widget> get fields => [
    ...super.fields,
    const NodeTextField(label: "Smooth Factor", field: "smooth")
  ];

  NormalizedEMA({super.id, super.ohlc, super.window, this.smooth = 0});

  factory NormalizedEMA.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);
    final window = getField<int>(json, "window");
    final smooth = getField<int>(json, "smooth");

    final node = NormalizedEMA(id: id, ohlc: ohlc, window: window, smooth: smooth);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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

  @override
  NodeData copy() {
    return NormalizedEMA.fromJson(toJson());
  }
}

class NormalizedMACD extends NodeData with FeatureChartInfo {
  @override
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
  String get featureName => "normalized_macd";

  @override
  String get outputName => output.name;

  @override
  bool get isBarChart => output == MACDOutput.hist;

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    OhlcDropdown(),
    NodeTextField(label: "Fast Window", field: "fast_window"),
    NodeTextField(label: "Fast Smooth Factor", field: "fast_smooth"),
    NodeTextField(label: "Slow Window", field: "slow_window"),
    NodeTextField(label: "Slow Smooth Factor", field: "slow_smooth"),
    NodeTextField(label: "Signal Window", field: "signal_window"),
    NodeTextField(label: "Signal Smooth Factor", field: "signal_smooth"),
    NodeDropdown<MACDOutput>(
      label: "output",
      field: "output",
      options: MACDOutput.values,
      optionLabel: NormalizedMACD._outputLabel
    )
  ];

  NormalizedMACD({this.id = "", this.ohlc = OHLC.close, this.fastWindow = 0, this.slowWindow = 0, this.signalWindow = 0, this.fastSmooth = 0, this.slowSmooth = 0, this.signalSmooth = 0, this.output = MACDOutput.line});

  static String _outputLabel(MACDOutput value) {
    return value.name;
  }

  factory NormalizedMACD.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);
    final fastWindow = getField<int>(json, "fast_window");
    final slowWindow = getField<int>(json, "slow_window");
    final signalWindow = getField<int>(json, "signal_window");
    final fastSmooth = getField<int>(json, "fast_smooth");
    final slowSmooth = getField<int>(json, "slow_smooth");
    final signalSmooth = getField<int>(json, "signal_smooth");
    final output = getField<MACDOutput>(json, "output", defaultValue: MACDOutput.line, fromJson: MACDOutput.fromJson);

    final node = NormalizedMACD(
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
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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
      "node_id": nodeId,
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

  @override
  NodeData copy() {
    return NormalizedMACD.fromJson(toJson());
  }
}

class RSI extends OhlcWindowFeature {
  int smooth;

  @override
  NodeType get nodeType => NodeType.rsi;

  @override
  String get featureName => "rsi";

  @override
  Map<double, String> get chartRefLines => {70.0: "70", 30.0: "30"};

  @override
  List<Widget> get fields => [
    ...super.fields,
    const NodeTextField(label: "Smooth Factor", field: "smooth")
  ];

  RSI({super.id, super.ohlc, super.window, this.smooth = 0});

  factory RSI.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);
    final window = getField<int>(json, "window");
    final smooth = getField<int>(json, "smooth");

    final node = RSI(id: id, ohlc: ohlc, window: window, smooth: smooth);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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

  @override
  NodeData copy() {
    return RSI.fromJson(toJson());
  }
}

class NormalizedBB extends NodeData with FeatureChartInfo {
  @override
  String id;
  OHLC ohlc;
  int window;
  double stdMultiplier;
  BBOutput output;

  @override
  NodeType get nodeType => NodeType.normalizedBb;

  @override
  String get featureName => "normalized_bb";

  @override
  String get outputName => output.name;

  @override
  Map<double, String> get chartRefLines => {1.0: "1.00"};

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    OhlcDropdown(),
    NodeTextField(label: "Window", field: "window"),
    NodeTextField(label: "Standard Deviation Multiplier", field: "std_multiplier"),
    NodeDropdown<BBOutput>(
      label: "output",
      field: "output",
      options: BBOutput.values,
      optionLabel: NormalizedBB._outputLabel
    )
  ];

  NormalizedBB({this.id = "", this.ohlc = OHLC.close, this.window = 0, this.stdMultiplier = 0.0, this.output = BBOutput.upper});

  static String _outputLabel(BBOutput value) {
    return value.name;
  }

  factory NormalizedBB.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);
    final window = getField<int>(json, "window");
    final stdMult = getField<double>(json, "std_multiplier");
    final output = getField<BBOutput>(json, "output", defaultValue: BBOutput.upper, fromJson: BBOutput.fromJson);

    final node = NormalizedBB(
      id: id,
      ohlc: ohlc,
      window: window,
      stdMultiplier: stdMult,
      output: output
    );
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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
      "node_id": nodeId,
      "feature": "normalized_bb",
      "id": id,
      "ohlc": ohlc.name,
      "window": window,
      "std_multiplier": stdMultiplier,
      "output": output.name
    };
  }

  @override
  NodeData copy() {
    return NormalizedBB.fromJson(toJson());
  }
}

class Stochastic extends NodeData with FeatureChartInfo {
  @override
  String id;
  int window;
  int smoothWindow;
  StochasticOutput output;

  @override
  NodeType get nodeType => NodeType.stochastic;

  @override
  String get featureName => "stochastic";

  @override
  String get outputName => output.toJson();

  @override
  Map<double, String> get chartRefLines => {80.0: "80", 20.0: "20"};

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    NodeTextField(label: "Window", field: "window"),
    NodeTextField(label: "Smooth Factor", field: "smooth_window"),
    NodeDropdown<StochasticOutput>(
      label: "output",
      field: "output",
      options: StochasticOutput.values,
      optionLabel: Stochastic._outputLabel
    )
  ];

  Stochastic({
    this.id = "",
    this.window = 0,
    this.smoothWindow = 0,
    this.output = StochasticOutput.percentK
  });

  static String _outputLabel(StochasticOutput value) {
    return value.toJson();
  }

  factory Stochastic.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final window = getField<int>(json, "window");
    final smoothWindow = getField<int>(json, "smooth_window");
    final output = getField<StochasticOutput>(json, "output", defaultValue: StochasticOutput.percentK, fromJson: StochasticOutput.fromJson);

    final node = Stochastic(id: id, window: window, smoothWindow: smoothWindow, output: output);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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
      "node_id": nodeId,
      "feature": "stochastic",
      "id": id,
      "window": window,
      "smooth_window": smoothWindow,
      "output": output.toJson()
    };
  }

  @override
  NodeData copy() {
    return Stochastic.fromJson(toJson());
  }
}

class NormalizedATR extends WindowFeature {
  int smooth;

  @override
  NodeType get nodeType => NodeType.atr;

  @override
  String get featureName => "normalized_atr";

  @override
  Map<double, String> get chartRefLines => {1.0: "1.00"};

  @override
  List<Widget> get fields => [
    ...super.fields,
    const NodeTextField(label: "Smooth Factor", field: "smooth")
  ];

  NormalizedATR({super.id, super.window, this.smooth = 0});

  factory NormalizedATR.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final window = getField<int>(json, "window");
    final smooth = getField<int>(json, "smooth");

    final node = NormalizedATR(id: id, window: window, smooth: smooth);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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

  @override
  NodeData copy() {
    return NormalizedATR.fromJson(toJson());
  }
}

class ROC extends OhlcWindowFeature {
  @override
  NodeType get nodeType => NodeType.roc;

  @override
  String get featureName => "roc";

  @override
  Map<double, String> get chartRefLines => {1.0: "1.00"};

  ROC({super.id, super.ohlc, super.window});

  factory ROC.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final ohlc = getField<OHLC>(json, "ohlc", defaultValue: OHLC.close, fromJson: OHLC.fromJson);
    final window = getField<int>(json, "window");

    final node = ROC(id: id, ohlc: ohlc, window: window);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
  }

  @override
  NodeData copy() {
    return ROC.fromJson(toJson());
  }
}

class NormalizedDC extends NodeData with FeatureChartInfo {
  @override
  String id;
  int window;
  DonchianOutput output;

  @override
  NodeType get nodeType => NodeType.normalizedDc;

  @override
  String get featureName => "normalized_dc";

  @override
  String get outputName => output.name;

  @override
  Map<double, String> get chartRefLines => {1.0: "1.00"};

  @override
  List<Widget> get fields => const [
    NodeTextField(label: "Feature ID", field: "id"),
    NodeTextField(label: "Window", field: "window"),
    NodeDropdown<DonchianOutput>(
      label: "output",
      field: "output",
      options: DonchianOutput.values,
      optionLabel: NormalizedDC._outputLabel
    )
  ];

  NormalizedDC({
    this.id = "",
    this.window = 0,
    this.output = DonchianOutput.upper
  });

  static String _outputLabel(DonchianOutput value) {
    return value.name;
  }

  factory NormalizedDC.fromJson(Map<String, dynamic> json) {
    final nodeId = json["node_id"];
    final id = getField<String>(json, "id");
    final window = getField<int>(json, "window");
    final output = getField<DonchianOutput>(json, "output", defaultValue: DonchianOutput.upper, fromJson: DonchianOutput.fromJson);

    final node = NormalizedDC(id: id, window: window, output: output);
    if (nodeId is String) {
      node.nodeId = nodeId;
    }
    return node;
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
      "node_id": nodeId,
      "feature": "normalized_dc",
      "id": id,
      "window": window,
      "output": output.name
    };
  }

  @override
  NodeData copy() {
    return NormalizedDC.fromJson(toJson());
  }
}
