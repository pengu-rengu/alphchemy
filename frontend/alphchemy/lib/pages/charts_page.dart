import "package:alphchemy/blocs/feature_set_bloc.dart";
import "package:alphchemy/widgets/charts/charts_view.dart";
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
        // ignore: prefer_const_constructors
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
