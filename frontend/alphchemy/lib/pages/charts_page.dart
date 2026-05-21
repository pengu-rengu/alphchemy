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
              return ChartsArea();
            }
          )
        )
      )
    );
  }
}

class ChartsArea extends StatelessWidget {

  const ChartsArea({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_literals_to_create_immutables, prefer_const_constructors
    return Column(children: [
      // ignore: prefer_const_constructors
      ChartsPageHeader(),
      const Divider(height: 1),
      // ignore: prefer_const_literals_to_create_immutables, prefer_const_constructors
      Expanded(child: Row(children: [
        // ignore: prefer_const_constructors
        Expanded(child: ChartsView()),
        const VerticalDivider(width: 1),
        // ignore: prefer_const_constructors
        SizedBox(
          width: 500,
          // ignore: prefer_const_constructors
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
    final bloc = context.read<FeatureSetBloc>();
    final loaded = bloc.state as FeatureSetLoaded;
    final title = loaded.featureSet.title;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Header(
          left: [
            IconButton(
              icon: const NormalIcon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop()
            ),
            const SizedBox(width: 10.0),
            LargeText(title),
            const SizedBox(width: 5.0),
            IconButton(
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
          right: [
            StaleIndicator(stale: loaded.stale),
            const UpdateButton()
          ]
        ),
        if (loaded.errorMessage != null) ErrorBanner(message: loaded.errorMessage!)
      ]
    );
  }
}
