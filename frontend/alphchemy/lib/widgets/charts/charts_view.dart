import "package:alphchemy/blocs/feature_set_bloc.dart";
import "package:alphchemy/model/experiment/features.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/widgets/charts/candlestick_panel.dart";
import "package:alphchemy/widgets/charts/feature_chart.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ChartsView extends StatelessWidget {
  const ChartsView({super.key});

  @override
  Widget build(BuildContext context) {
    final featureSet = (context.read<FeatureSetBloc>().state as FeatureSetLoaded).featureSet;
    final values = featureSet.values;
    final ohlc = values?.ohlc;

    if (featureSet.status == FeatureSetStatus.errored) {
      return ChartsErrorView(message: values?.error ?? "");
    }
    if (featureSet.status == FeatureSetStatus.working) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(10.0),
      children: [
        if (ohlc != null)
          CandlestickPanel(ohlc: ohlc)
        else
          const PaddedCard(child: Center(child: NormalText("No OHLC values yet — click \"Request Values\""))),
        const SizedBox(height: 10.0),
        ...featureSet.feats.expand((feat) {
          final info = feat as FeatureChartInfo;
          return [
            FeatureChart(
              info: info,
              values: values?.featTable[info.id],
              timestamps: ohlc?.timestamp ?? const <double>[]
            ),
            const SizedBox(height: 10.0)
          ];
        }),
        const SizedBox(height: 50.0)
      ]
    );
  }
}

class ChartsErrorView extends StatelessWidget {
  final String message;

  const ChartsErrorView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NormalIcon(Icons.error_outline),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium
        )
      ]
    ));
  }
}
