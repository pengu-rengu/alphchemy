import "package:alphchemy/objects/features.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);

class ConstantFeatureContent extends StatelessWidget {
  const ConstantFeatureContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "featId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "featId", fieldKey: "featId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "constant",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "constant", fieldKey: "constant"),
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
        const ParamField(
          fieldKey: "featId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "featId", fieldKey: "featId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "returnsType",
          paramType: ParamType.stringType,
          child: NodeDropdown<ReturnsType>(
            label: "returns",
            fieldKey: "returnsType",
            options: ReturnsType.values,
            labelFor: (val) => val.name,
          ),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "ohlc",
          paramType: ParamType.stringType,
          child: NodeDropdown<OHLC>(
            label: "ohlc",
            fieldKey: "ohlc",
            options: OHLC.values,
            labelFor: (val) => val.name,
          ),
        ),
      ],
    );
  }
}
