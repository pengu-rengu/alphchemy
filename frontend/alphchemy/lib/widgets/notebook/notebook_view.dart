import "package:alphchemy/blocs/notebook_bloc.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/notebook/notebook_tile.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class NotebookView extends StatelessWidget {
  const NotebookView({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = context.read<NotebookBloc>().state as NotebookLoaded;
    final notebook = loaded.notebook;

    if (notebook.status == NotebookStatus.working) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notebook.status == NotebookStatus.errored) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NormalIcon(Icons.error_outline),
          SizedBox(height: 10.0),
          NormalText("Notebook run failed")
        ]
      ));
    }

    final layout = notebook.layout;
    if (layout.left.isEmpty && layout.right.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NormalText("No tiles yet"),
          const SizedBox(height: 10.0),
          FilledButton.icon(
            onPressed: () {
              const event = AddTile(left: true);
              context.read<NotebookBloc>().add(event);
            },
            icon: const InvertedIcon(Icons.add),
            label: const InvertedText("New tile")
          )
        ]
      ));
    }

    // ignore: prefer_const_constructors
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      // ignore: prefer_const_constructors
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // ignore: prefer_const_literals_to_create_immutables
        children: [
          // ignore: prefer_const_constructors
          Expanded(child: _TileColumn(left: true)),
          const SizedBox(width: 10.0),
          // ignore: prefer_const_constructors
          Expanded(child: _TileColumn(left: false))
        ]
      )
    );
  }
}

class _TileColumn extends StatelessWidget {
  final bool left;

  const _TileColumn({required this.left});

  @override
  Widget build(BuildContext context) {
    final notebook = (context.read<NotebookBloc>().state as NotebookLoaded).notebook;
    final layout = notebook.layout;
    final tileIds = left ? layout.left : layout.right;
    final queryById = <String, Query>{for (final query in notebook.queries) query.id: query};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tileId in tileIds)
          if (queryById[tileId] case final query?)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: NotebookTile(
                key: ValueKey<String>(tileId),
                query: query,
                note: notebook.notes[tileId] ?? ""
              )
            ),
        Center(child: FilledButton.icon(
          onPressed: () {
            final event = AddTile(left: left);
            context.read<NotebookBloc>().add(event);
          },
          icon: const InvertedIcon(Icons.add),
          label: const InvertedText("New tile")
        ))
      ]
    );
  }
}
