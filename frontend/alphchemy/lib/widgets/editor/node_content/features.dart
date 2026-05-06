import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class _FeatureIdField extends StatelessWidget {
  const _FeatureIdField();

  @override
  Widget build(BuildContext context) {
    return const NodeTextField(label: "featId", fieldKey: "id");
  }
}

class _WindowField extends StatelessWidget {
  const _WindowField();

  @override
  Widget build(BuildContext context) {
    return const NodeTextField(label: "window", fieldKey: "window");
  }
}

class _OhlcDropdown extends StatelessWidget {
  const _OhlcDropdown();

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<OHLC>(
      label: "ohlc",
      fieldKey: "ohlc",
      options: OHLC.values,
      optionLabel: (value) => value.name
    );
  }
}

class _OhlcWindowFeatureContent extends StatelessWidget {
  const _OhlcWindowFeatureContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeatureIdField(),
        _fieldGap,
        _OhlcDropdown(),
        _fieldGap,
        _WindowField()
      ]
    );
  }
}

class _WindowFeatureContent extends StatelessWidget {
  const _WindowFeatureContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeatureIdField(),
        _fieldGap,
        _WindowField()
      ]
    );
  }
}

class ConstantFeatureContent extends StatelessWidget {
  const ConstantFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeatureIdField(),
        _fieldGap,
        NodeTextField(
          label: "constant",
          fieldKey: "constant"
        )
      ]
    );
  }
}

class RawReturnsFeatureContent extends StatelessWidget {
  const RawReturnsFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _FeatureIdField(),
        _fieldGap,
        NodeDropdown<ReturnsType>(
          label: "returns",
          fieldKey: "returns_type",
          options: ReturnsType.values,
          optionLabel: (value) => value.name
        ),
        _fieldGap,
        const _OhlcDropdown()
      ]
    );
  }
}

class SmaFeatureContent extends StatelessWidget {
  const SmaFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OhlcWindowFeatureContent();
  }
}

class EmaFeatureContent extends StatelessWidget {
  const EmaFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OhlcWindowFeatureContent();
  }
}

class MacdFeatureContent extends StatelessWidget {
  const MacdFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _FeatureIdField(),
        _fieldGap,
        const _OhlcDropdown(),
        _fieldGap,
        const NodeTextField(label: "fast", fieldKey: "fast_window"),
        _fieldGap,
        const NodeTextField(label: "slow", fieldKey: "slow_window"),
        _fieldGap,
        const NodeTextField(label: "signal", fieldKey: "signal_window"),
        _fieldGap,
        NodeDropdown<MacdOutput>(
          label: "output",
          fieldKey: "output",
          options: MacdOutput.values,
          optionLabel: (value) => value.toJson()
        )
      ]
    );
  }
}

class RsiFeatureContent extends StatelessWidget {
  const RsiFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OhlcWindowFeatureContent();
  }
}

class BollingerBandsFeatureContent extends StatelessWidget {
  const BollingerBandsFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _FeatureIdField(),
        _fieldGap,
        const _OhlcDropdown(),
        _fieldGap,
        const _WindowField(),
        _fieldGap,
        const NodeTextField(label: "stdMult", fieldKey: "std_mult"),
        _fieldGap,
        NodeDropdown<BollingerOutput>(
          label: "output",
          fieldKey: "output",
          options: BollingerOutput.values,
          optionLabel: (value) => value.toJson()
        )
      ]
    );
  }
}

class StochasticFeatureContent extends StatelessWidget {
  const StochasticFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _FeatureIdField(),
        _fieldGap,
        const _WindowField(),
        _fieldGap,
        const NodeTextField(label: "smooth", fieldKey: "smooth_window"),
        _fieldGap,
        NodeDropdown<StochasticOutput>(
          label: "output",
          fieldKey: "output",
          options: StochasticOutput.values,
          optionLabel: (value) => value.toJson()
        )
      ]
    );
  }
}

class AtrFeatureContent extends StatelessWidget {
  const AtrFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WindowFeatureContent();
  }
}

class RocFeatureContent extends StatelessWidget {
  const RocFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OhlcWindowFeatureContent();
  }
}

class MomentumFeatureContent extends StatelessWidget {
  const MomentumFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OhlcWindowFeatureContent();
  }
}

class DonchianChannelFeatureContent extends StatelessWidget {
  const DonchianChannelFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _FeatureIdField(),
        _fieldGap,
        const _WindowField(),
        _fieldGap,
        NodeDropdown<DonchianOutput>(
          label: "output",
          fieldKey: "output",
          options: DonchianOutput.values,
          optionLabel: (value) => value.toJson()
        )
      ]
    );
  }
}

class CciFeatureContent extends StatelessWidget {
  const CciFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WindowFeatureContent();
  }
}
