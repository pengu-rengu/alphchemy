import "package:alphchemy/blocs/feature_set_bloc.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/widgets/charts/candlestick_panel.dart";
import "package:alphchemy/widgets/charts/feature_panel.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ChartsView extends StatelessWidget {
  const ChartsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    final values = state.featureSet.values;
    final feats = state.featureSet.feats;
    final errorMessage = values?.error;
    final showError = state.featureSet.status == FeatureSetStatus.errored && errorMessage != null;
    final ohlc = values?.ohlc;
    final hasOhlc = ohlc != null && ohlc.close.isNotEmpty;

    if (showError) {
      return ChartsErrorView(message: errorMessage);
    }

    return ListView(
      padding: const EdgeInsets.all(10.0),
      children: [
        if (hasOhlc)
          CandlestickPanel(ohlc: ohlc)
        else
          const PaddedCard(child: Center(child: NormalText("No OHLC values yet — click \"Request Values\""))),
        const SizedBox(height: 10),
        for (final feat in feats) ...[
          FeatureChartTile(feat: feat, values: values?.featTable[feat.formatField("id")] ?? const []),
          const SizedBox(height: 10)
        ]
      ]
    );
  }
}

class ChartsErrorView extends StatelessWidget {
  final String message;

  const ChartsErrorView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NormalIcon(Icons.error_outline),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium
              )
            ]
          )
        )
      )
    );
  }
}

class FeatureChartTile extends StatelessWidget {
  final NodeData feat;
  final List<double> values;

  const FeatureChartTile({super.key, required this.feat, required this.values});

  @override
  Widget build(BuildContext context) {
    final json = feat.toJson();
    final featureName = json["feature"] as String? ?? "";
    final output = json["output"] as String? ?? "";
    final id = (json["id"] as String?) ?? feat.nodeId;

    return FeaturePanel(
      featureId: id,
      featureName: featureName,
      output: output,
      values: values
    );
  }
}
