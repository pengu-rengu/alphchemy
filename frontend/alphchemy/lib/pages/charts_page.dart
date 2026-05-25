import "package:alphchemy/blocs/feature_sets/feature_set_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/charts/charts_view.dart";
import "package:alphchemy/widgets/charts/feature_set_editor.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
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
      // ignore: prefer_const_constructors
      child: Scaffold(
        // ignore: prefer_const_constructors
        body: SafeArea(
          child: const ChartsArea()
        )
      )
    );
  }
}

class ChartsArea extends StatelessWidget {

  const ChartsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureSetBloc, FeatureSetState>(
      builder: (context, state) {
        return Column(children: [
          // ignore: prefer_const_constructors
          ChartsHeader(),
          const Divider(height: 1),
          switch (state) {
            FeatureSetInitial() => const LoadingIndicator(),
            FeatureSetError() => CenterText(state.message, expanded: true),
            // ignore: prefer_const_constructors
            FeatureSetLoaded() => Expanded(child: ChartsContent())
          }
        ]);
      }
    );
  }
}

class ChartsContent extends StatelessWidget {
  const ChartsContent({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_constructors
    return Row(
      // ignore: prefer_const_literals_to_create_immutables
      children: [
        // ignore: prefer_const_constructors
        ChartsView(),
        const VerticalDivider(width: 1),
        // ignore: prefer_const_constructors
        SizedBox(
          width: 500,
          // ignore: prefer_const_constructors
          child: FeatureSetEditor()
        )
      ]
    );
  }
}

class ChartsHeader extends StatelessWidget {
  const ChartsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FeatureSetBloc>();
    final state = bloc.state;
    final loaded = state is FeatureSetLoaded ? state : null;
    final title = loaded?.featureSet.title ?? "Feature Set";

    return Header(
      left: [
        IconButton(
          icon: const NormalIcon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop()
        ),
        const SizedBox(width: 10.0),
        LargeText(title),
        const SizedBox(width: 5.0),
        if (loaded != null) IconButton(
          onPressed: () async {
            final newTitle = await renameDialog(context: context, title: title);
            if (!context.mounted || newTitle == null) {
              return;
            }

            final event = RenameFeatureSet(title: newTitle);
            bloc.add(event);
          },
          icon: const NormalIcon(Icons.edit)
        )
      ],
      right: loaded == null ? [] : [
        StaleIndicator(stale: loaded.stale),
        const UpdateButton()
      ],
      errorMessage: loaded?.errorMessage
    );
  }
}
