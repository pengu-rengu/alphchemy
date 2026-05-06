import "package:alphchemy/widgets/editor/node_content/network.dart";
import "package:alphchemy/widgets/editor/node_fields.dart";
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
          fieldKey: "start_offset"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "startBal",
          fieldKey: "start_balance"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "delay",
          fieldKey: "delay"
        )
      ]
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
          fieldKey: "id"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "posSize",
          fieldKey: "position_size"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxPos",
          fieldKey: "max_positions"
        )
      ]
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
          fieldKey: "id"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "entries",
          fieldKey: "entry_ids"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "stopLoss",
          fieldKey: "stop_loss"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "takeProfit",
          fieldKey: "take_profit"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "maxHold",
          fieldKey: "max_hold_time"
        )
      ]
    );
  }
}

class ActionsContent extends StatelessWidget {
  const ActionsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<String>(
      label: "type",
      fieldKey: "type",
      options: networkTypes,
      optionLabel: (val) => val
    );
  }
}

class StrategyContent extends StatelessWidget {
  const StrategyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "maxPos",
          fieldKey: "global_max_positions"
        )
      ]
    );
  }
}

class ExperimentContent extends StatelessWidget {
  const ExperimentContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "title",
          fieldKey: "title"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "valSize",
          fieldKey: "val_size"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "testSize",
          fieldKey: "test_size"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "cvFolds",
          fieldKey: "cv_folds"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "foldSize",
          fieldKey: "fold_size"
        )
      ]
    );
  }
}
