import "package:alphchemy/blocs/feature_sets/feature_sets_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/pages/charts_page.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class FeatureSetsPage extends StatelessWidget {
  const FeatureSetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FeatureSetsBloc>(
      create: (_) {
        final client = context.read<SupabaseClient>();
        final bloc = FeatureSetsBloc(client: client);
        bloc.add(const LoadFeatureSets());
        return bloc;
      },
      child: const PageScaffold(
        selectedIdx: 2,
        child: FeatureSetsBody()
      )
    );
  }
}

class FeatureSetsBody extends StatelessWidget {
  const FeatureSetsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const FeatureSetsHeader(),
      const Divider(height: 1),
      Expanded(child: BlocBuilder<FeatureSetsBloc, FeatureSetsState>(
        builder: (context, state) {
          if (state is FeatureSetsError) {
            return Center(child: NormalText(state.message));
          }
          if (state is! FeatureSetsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return FeatureSetsList(summaries: state.summaries);
        }
      ))
    ]);
  }
}

class FeatureSetsHeader extends StatelessWidget {
  const FeatureSetsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Header(
      left: const [LargeText("Feature Sets")],
      right: [FilledButton.icon(
        onPressed: () {
          final event = CreateFeatureSet(
            title: "Untitled",
            onCreated: (id) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChartsPage(featureSetId: id)
              ));
            }
          );
          context.read<FeatureSetsBloc>().add(event);
        },
        icon: const InvertedIcon(Icons.add),
        label: const InvertedText("New Feature Set")
      )]
    );
  }
}

class FeatureSetsList extends StatelessWidget {
  final List<FeatureSetSummary> summaries;

  const FeatureSetsList({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Center(child: NormalText("No feature sets yet"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: summaries.length,
      itemBuilder: (context, idx) {
        return FeatureSetCard(summary: summaries[idx]);
      } 
    );
  }
}

class FeatureSetCard extends StatelessWidget {
  final FeatureSetSummary summary;

  const FeatureSetCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: Row(children: [
      NormalText(summary.title),
      const Spacer(),
      IconButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChartsPage(featureSetId: summary.id)
          ));
        },
        icon: const NormalIcon(Icons.open_in_new)
      ),
      IconButton(
        onPressed: () async {
          final confirmed = await confirmDeleteDialog(context: context, title: summary.title);
          if (!context.mounted || !confirmed) {
            return;
          }

          final event = DeleteFeatureSet(id: summary.id);
          context.read<FeatureSetsBloc>().add(event);
        },
        icon: const NormalIcon(Icons.delete)
      )
    ]));
  }
}
