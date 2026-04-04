import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";

const _fieldGap = SizedBox(height: 2);
const _generatorTypes = ["logic", "decision"];

class BacktestSchemaContent extends StatelessWidget {
  const BacktestSchemaContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "startOffset",
          paramType: ParamType.intType,
          child: NodeTextField(label: "startOffset", fieldKey: "startOffset"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "startBalance",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "startBal", fieldKey: "startBalance"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "delay",
          paramType: ParamType.intType,
          child: NodeTextField(label: "delay", fieldKey: "delay"),
        ),
      ],
    );
  }
}

class EntrySchemaContent extends StatelessWidget {
  const EntrySchemaContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "entryId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "id", fieldKey: "entryId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "positionSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "posSize", fieldKey: "positionSize"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "maxPositions",
          paramType: ParamType.intType,
          child: NodeTextField(label: "maxPos", fieldKey: "maxPositions"),
        ),
      ],
    );
  }
}

class ExitSchemaContent extends StatelessWidget {
  const ExitSchemaContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "exitId",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "id", fieldKey: "exitId"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "entryIds",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "entries", fieldKey: "entryIds"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "stopLoss",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "stopLoss", fieldKey: "stopLoss"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "takeProfit",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "takeProfit", fieldKey: "takeProfit"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "maxHoldTime",
          paramType: ParamType.intType,
          child: NodeTextField(label: "maxHold", fieldKey: "maxHoldTime"),
        ),
      ],
    );
  }
}

class NetworkGenContent extends StatelessWidget {
  const NetworkGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ParamField(
      fieldKey: "type",
      paramType: ParamType.stringType,
      child: NodeDropdown<String>(
        label: "type",
        fieldKey: "type",
        options: _generatorTypes,
        labelFor: (val) => val,
      ),
    );
  }
}

class PenaltiesGenContent extends StatelessWidget {
  const PenaltiesGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ParamField(
      fieldKey: "type",
      paramType: ParamType.stringType,
      child: NodeDropdown<String>(
        label: "type",
        fieldKey: "type",
        options: _generatorTypes,
        labelFor: (val) => val,
      ),
    );
  }
}

class ActionsGenContent extends StatelessWidget {
  const ActionsGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ParamField(
      fieldKey: "type",
      paramType: ParamType.stringType,
      child: NodeDropdown<String>(
        label: "type",
        fieldKey: "type",
        options: _generatorTypes,
        labelFor: (val) => val,
      ),
    );
  }
}

class StrategyGenContent extends StatelessWidget {
  const StrategyGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "featSelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "featSel", fieldKey: "featSelection"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "globalMaxPositions",
          paramType: ParamType.intType,
          child: NodeTextField(label: "maxPos", fieldKey: "globalMaxPositions"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "entrySelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "entrySel", fieldKey: "entrySelection"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "exitSelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "exitSel", fieldKey: "exitSelection"),
        ),
      ],
    );
  }
}

class ExperimentGenContent extends StatelessWidget {
  const ExperimentGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParamField(
          fieldKey: "title",
          paramType: ParamType.stringType,
          child: NodeTextField(label: "title", fieldKey: "title"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "valSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "valSize", fieldKey: "valSize"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "testSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "testSize", fieldKey: "testSize"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "cvFolds",
          paramType: ParamType.intType,
          child: NodeTextField(label: "cvFolds", fieldKey: "cvFolds"),
        ),
        _fieldGap,
        ParamField(
          fieldKey: "foldSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "foldSize", fieldKey: "foldSize"),
        ),
      ],
    );
  }
}
