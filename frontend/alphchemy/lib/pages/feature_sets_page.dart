import "package:alphchemy/blocs/feature_sets_bloc.dart";
import "package:alphchemy/model/feature_set/feature_set_summary.dart";
import "package:alphchemy/pages/charts_page.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:alphchemy/widgets/widget_utils.dart";
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
        selectedIdx: 3,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(children: [
        const LargeText("Feature Sets"),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => _createFeatureSet(context),
          icon: const InvertedIcon(Icons.add),
          label: const InvertedText("New Feature Set")
        )
      ])
    );
  }

  void _createFeatureSet(BuildContext context) {
    final bloc = context.read<FeatureSetsBloc>();
    final navigator = Navigator.of(context);
    final event = CreateFeatureSet(
      title: "Untitled Feature Set",
      onCreated: (id) {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => ChartsPage(featureSetId: id)
        ));
      }
    );
    bloc.add(event);
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
      itemBuilder: (context, index) => FeatureSetTile(summary: summaries[index])
    );
  }
}

class FeatureSetTile extends StatelessWidget {
  final FeatureSetSummary summary;

  const FeatureSetTile({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: ListTile(
      dense: true,
      title: NormalText(summary.title),
      subtitle: NormalText(summary.status.label),
      trailing: IconButton(
        tooltip: "Delete feature set",
        icon: const NormalIcon(Icons.delete_outline),
        onPressed: () => _delete(context)
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChartsPage(featureSetId: summary.id)
        ));
      }
    ));
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LargeText("Delete Feature Set"),
        content: NormalText("Delete feature set ${summary.title}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const NormalText("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const NormalText("Delete")
          )
        ]
      )
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<FeatureSetsBloc>().add(DeleteFeatureSet(id: summary.id));
  }
}
