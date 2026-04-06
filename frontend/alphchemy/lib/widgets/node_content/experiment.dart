import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:alphchemy/widgets/param_field.dart";
import "package:flutter/widgets.dart";

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
        SizedBox(height: 2),
        ParamField(
          fieldKey: "startBalance",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "startBal", fieldKey: "startBalance"),
        ),
        SizedBox(height: 2),
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
        SizedBox(height: 2),
        ParamField(
          fieldKey: "positionSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "posSize", fieldKey: "positionSize"),
        ),
        SizedBox(height: 2),
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
        SizedBox(height: 2),
        ParamField(
          fieldKey: "entryIds",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "entries", fieldKey: "entryIds"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "stopLoss",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "stopLoss", fieldKey: "stopLoss"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "takeProfit",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "takeProfit", fieldKey: "takeProfit"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "maxHoldTime",
          paramType: ParamType.intType,
          child: NodeTextField(label: "maxHold", fieldKey: "maxHoldTime"),
        ),
      ],
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
        SizedBox(height: 2),
        ParamField(
          fieldKey: "globalMaxPositions",
          paramType: ParamType.intType,
          child: NodeTextField(label: "maxPos", fieldKey: "globalMaxPositions"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "entrySelection",
          paramType: ParamType.stringListType,
          child: NodeTextField(label: "entrySel", fieldKey: "entrySelection"),
        ),
        SizedBox(height: 2),
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
        SizedBox(height: 2),
        ParamField(
          fieldKey: "valSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "valSize", fieldKey: "valSize"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "testSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "testSize", fieldKey: "testSize"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "cvFolds",
          paramType: ParamType.intType,
          child: NodeTextField(label: "cvFolds", fieldKey: "cvFolds"),
        ),
        SizedBox(height: 2),
        ParamField(
          fieldKey: "foldSize",
          paramType: ParamType.floatType,
          child: NodeTextField(label: "foldSize", fieldKey: "foldSize"),
        ),
      ],
    );
  }
}
