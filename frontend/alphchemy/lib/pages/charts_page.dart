import "package:alphchemy/blocs/feature_set_bloc.dart";
import "package:alphchemy/main.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/charts/candlestick_panel.dart";
import "package:alphchemy/widgets/charts/feature_panel.dart";
import "package:alphchemy/widgets/charts/feature_set_editor.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ChartsPage extends StatelessWidget {
  final int featureSetId;

  const ChartsPage({super.key, required this.featureSetId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FeatureSetBloc>(
      create: (_) {
        final client = context.read<SupabaseClient>();
        final bloc = FeatureSetBloc(client: client);
        bloc.add(SubscribeToFeatureSet(id: featureSetId));
        return bloc;
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<FeatureSetBloc, FeatureSetState>(
            builder: (context, state) {
              
              if (state is FeatureSetError) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NormalText(state.message),
                    IconButton(
                      icon: const NormalIcon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop()
                    )
                  ]
                ));
              }
              if (state is! FeatureSetLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              // ignore: prefer_const_constructors
              return ChartsPageBody();
            }
          )
        )
      )
    );
  }
}

class ChartsPageBody extends StatelessWidget {

  const ChartsPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ChartsPageHeader(),
      const Divider(height: 1),
      Expanded(child: Row(children: [
        Expanded(child: ChartsColumn()),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 500,
          child: FeatureSetEditor()
        )
      ]))
    ]);
  }
}

class ChartsPageHeader extends StatelessWidget {
  const ChartsPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    final title = state.featureSet.title;

    return Padding(
      padding: const EdgeInsetsGeometry.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(children: [
        IconButton(
          icon: const NormalIcon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop()
        ),
        const SizedBox(width: 10.0),
        LargeText(title),
        const SizedBox(width: 5.0),
        IconButton(
          onPressed: () => _showRenameDialog(context, title),
          icon: const NormalIcon(Icons.edit)
        ),
        const Spacer(),
        RequestValuesButton()
      ])
    );
  }

  Future<void> _showRenameDialog(BuildContext context, String currentTitle) async {
    final bloc = context.read<FeatureSetBloc>();
    final controller = TextEditingController(text: currentTitle);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LargeText("Rename feature set"),
        content: TextField(
          controller: controller,
          autofocus: true
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const NormalText("Cancel")
          ),
          TextButton(
            onPressed: () {
              final event = RenameFeatureSet(title: controller.text);
              bloc.add(event);
              Navigator.of(dialogContext).pop();
            },
            child: const NormalText("Rename")
          )
        ]
      )
    );
  }
}

class ChartsColumn extends StatelessWidget {
  const ChartsColumn({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<FeatureSetBloc>().state as FeatureSetLoaded;
    final values = state.featureSet.values;
    final feats = state.featureSet.feats;
    final ohlc = values?.ohlc;
    final hasOhlc = ohlc != null && ohlc.close.isNotEmpty;

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
