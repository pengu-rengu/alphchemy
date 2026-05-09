import "package:alphchemy/widgets/editor/node_fields.dart";
import "package:flutter/widgets.dart";

class BacktestSchemaFields extends StatelessWidget {
  const BacktestSchemaFields({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "start offset",
          fieldKey: "start_offset"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "start balance",
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

class EntrySchemaFields extends StatelessWidget {
  const EntrySchemaFields({super.key});

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
          label: "positions size",
          fieldKey: "position_size"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "max positions",
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

class StrategyContent extends StatelessWidget {
  const StrategyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "global max positions",
          fieldKey: "global_max_positions"
        )
      ]
    );
  }
}

class ExperimentFields extends StatelessWidget {
  const ExperimentFields({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NodeTextField(
          label: "validation size",
          fieldKey: "val_size"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "test size",
          fieldKey: "test_size"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "cv folds",
          fieldKey: "cv_folds"
        ),
        SizedBox(height: 2),
        NodeTextField(
          label: "fold size",
          fieldKey: "fold_size"
        )
      ]
    );
  }
}
