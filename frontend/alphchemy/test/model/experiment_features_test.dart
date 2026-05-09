import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("round trips indicator feature json", () {
    final samples = <Map<String, dynamic>>[
      {"feature": "normalized_sma", "id": "sma_close", "ohlc": "close", "window": 20},
      {"feature": "normalized_ema", "id": "ema_close", "ohlc": "close", "window": 20, "smooth": 2},
      {"feature": "normalized_macd", "id": "macd_close", "ohlc": "close", "fast_window": 12, "slow_window": 26, "signal_window": 9, "fast_smooth": 2, "slow_smooth": 2, "signal_smooth": 2, "output": "hist"},
      {"feature": "rsi", "id": "rsi_close", "ohlc": "close", "window": 14, "smooth": 2},
      {"feature": "normalized_bb", "id": "bb_close", "ohlc": "close", "window": 20, "std_multiplier": 2.0, "output": "upper"},
      {"feature": "stochastic", "id": "stoch_close", "window": 14, "smooth_window": 3, "output": "percent_k"},
      {"feature": "normalized_atr", "id": "atr_close", "window": 14, "smooth": 2},
      {"feature": "roc", "id": "roc_close", "ohlc": "close", "window": 10},
      {"feature": "normalized_dc", "id": "donchian_close", "window": 20, "output": "middle"}
    ];

    for (final sample in samples) {
      final feature = Strategy.featureFromJson(sample);
      expect(feature.toJson(), sample);
    }
  });

  test("strategy feature slot allows indicator nodes", () {
    final strategy = Strategy();
    final slot = strategy.childSlots.firstWhere((slot) => slot.key == "feats");

    expect(slot.allowedTypes, contains(NodeType.smaFeature));
    expect(slot.allowedTypes, contains(NodeType.macdFeature));
    expect(slot.allowedTypes, contains(NodeType.donchianChannelFeature));
  });

  test("creates empty indicator nodes", () {
    final macd = Experiment.createEmptyNode(NodeType.macdFeature);
    final bollinger = Experiment.createEmptyNode(NodeType.bollingerBandsFeature);

    expect(macd, isA<Macd>());
    expect(bollinger, isA<BollingerBands>());
  });
}
