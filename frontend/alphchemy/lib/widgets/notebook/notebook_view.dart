import "package:alphchemy/blocs/notebooks/notebook_bloc.dart";
import "package:alphchemy/model/notebook/notebook.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/notebook/notebook_tile.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class NotebookView extends StatelessWidget {
  final Notebook notebook;
  final bool readOnly;

  const NotebookView({super.key, required this.notebook, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    if (notebook.status == NotebookStatus.working) {
      return const Center(child: CircularProgressIndicator());
    }

    final layout = notebook.layout;
    final layoutEmpty = layout.left.isEmpty && layout.right.isEmpty;
    if (layoutEmpty && readOnly) {
      return const Center(child: NormalText("No tiles yet"));
    }

    if (layoutEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: TileColumn(notebook: notebook, left: true, readOnly: readOnly)),
          const SizedBox(width: 10.0),
          Expanded(child: TileColumn(notebook: notebook, left: false, readOnly: readOnly))
        ]
      )
    );
  }
}

class TileColumn extends StatelessWidget {
  final Notebook notebook;
  final bool left;
  final bool readOnly;

  const TileColumn({super.key, required this.notebook, required this.left, required this.readOnly});

  @override
  Widget build(BuildContext context) {
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
                note: notebook.notes[tileId] ?? "failed to find note",
                readOnly: readOnly
              )
            ),
        if (!readOnly)
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
