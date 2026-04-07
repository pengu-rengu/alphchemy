import "package:alphchemy/model/generator/param_space.dart";
import "package:alphchemy/widgets/node_fields.dart";
import "package:flutter/widgets.dart";

class BacktestSchemaContent extends StatelessWidget {
  const BacktestSchemaContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "startOffset",
          fieldKey: "start_offset",
          paramType: ParamType.intType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "startBal",
          fieldKey: "start_balance",
          paramType: ParamType.floatType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "delay",
          fieldKey: "delay",
          paramType: ParamType.intType,
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
        NodeTextField(
          label: "id",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "posSize",
          fieldKey: "position_size",
          paramType: ParamType.floatType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxPos",
          fieldKey: "max_positions",
          paramType: ParamType.intType,
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
        NodeTextField(
          label: "id",
          fieldKey: "id",
          paramType: ParamType.stringType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "entries",
          fieldKey: "entry_ids",
          paramType: ParamType.stringListType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "stopLoss",
          fieldKey: "stop_loss",
          paramType: ParamType.floatType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "takeProfit",
          fieldKey: "take_profit",
          paramType: ParamType.floatType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxHold",
          fieldKey: "max_hold_time",
          paramType: ParamType.intType,
        ),
      ],
    );
  }
}

class ActionsGenContent extends StatelessWidget {
  const ActionsGenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      fieldKey: "type",
      paramType: ParamType.stringType,
      options: const ["logic", "decision"],
      labelFor: (val) => val,
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
        NodeTextField(
          label: "featSel",
          fieldKey: "feat_selection",
          paramType: ParamType.stringListType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxPos",
          fieldKey: "global_max_positions",
          paramType: ParamType.intType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "entrySel",
          fieldKey: "entry_selection",
          paramType: ParamType.stringListType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "exitSel",
          fieldKey: "exit_selection",
          paramType: ParamType.stringListType,
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
        NodeTextField(
          label: "title",
          fieldKey: "title",
          paramType: ParamType.stringType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "valSize",
          fieldKey: "val_size",
          paramType: ParamType.floatType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "testSize",
          fieldKey: "test_size",
          paramType: ParamType.floatType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "cvFolds",
          fieldKey: "cv_folds",
          paramType: ParamType.intType,
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "foldSize",
          fieldKey: "fold_size",
          paramType: ParamType.floatType,
        ),
      ],
    );
  }
}
