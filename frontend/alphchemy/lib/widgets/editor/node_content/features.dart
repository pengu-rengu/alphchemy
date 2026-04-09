import "package:alphchemy/model/generator/features.dart";
import "package:alphchemy/model/generator/param_space.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class ConstantFeatureContent extends StatelessWidget {
  const ConstantFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "featId",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeTextField(
          label: "constant",
          fieldKey: "constant",
          paramType: ParamType.floatType,
        ),
      ],
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
        const NodeTextField(
          label: "featId",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        _fieldGap,
        NodeDropdown<ReturnsType>(
          label: "returns",
          fieldKey: "returns_type",
          paramType: ParamType.stringType,
          options: ReturnsType.values,
          labelFor: (val) => val.name,
        ),
        _fieldGap,
        NodeDropdown<OHLC>(
          label: "ohlc",
          fieldKey: "ohlc",
          paramType: ParamType.stringType,
          options: OHLC.values,
          labelFor: (val) => val.name,
        ),
      ],
    );
  }
}
