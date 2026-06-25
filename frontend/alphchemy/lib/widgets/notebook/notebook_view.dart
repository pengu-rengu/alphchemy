import "package:alphchemy/blocs/notebooks/notebook_bloc.dart";
import "package:alphchemy/model/notebook/notebook.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
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

    if (notebook.queries.isEmpty && !readOnly) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const NormalText("No tiles yet"),
          const SizedBox(height: 10.0),
          FilledButton.icon(
            onPressed: () {
              const event = AddTile();
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
      child: TileColumn(notebook: notebook, readOnly: readOnly)
    );
  }
}

class TileColumn extends StatelessWidget {
  final Notebook notebook;
  final bool readOnly;

  const TileColumn({super.key, required this.notebook, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < notebook.queries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: NotebookTile(
              key: ValueKey<int>(i),
              idx: i,
              query: notebook.queries[i],
              note: notebook.notes[i],
              readOnly: readOnly
            )
          ),
        if (!readOnly)
          Center(child: FilledButton.icon(
            onPressed: () {
              const event = AddTile();
              context.read<NotebookBloc>().add(event);
            },
            icon: const InvertedIcon(Icons.add),
            label: const InvertedText("New tile")
          ))
      ]
    );
  }
}
