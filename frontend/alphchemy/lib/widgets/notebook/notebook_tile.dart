import "package:alphchemy/blocs/notebooks/notebook_bloc.dart";
import "package:alphchemy/model/notebook/filter.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/notebook/box_plot.dart";
import "package:alphchemy/widgets/notebook/filter_row.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class NotebookTile extends StatelessWidget {
  final Query query;
  final String note;
  final bool readOnly;

  const NotebookTile({super.key, required this.query, required this.note, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TileHeader(tileId: query.id, readOnly: readOnly),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: NoteBlock(query: query, note: note, readOnly: readOnly)
          ),
          const Divider(height: 1),
          FilterSection(query: query, note: note, readOnly: readOnly),
          const Divider(height: 1),
          SelectionSection(query: query, note: note, readOnly: readOnly),
          const Divider(height: 1),
          ResultsSection(query: query)
        ]
      )
    );
  }
}

class TileHeader extends StatelessWidget {
  final String tileId;
  final bool readOnly;

  const TileHeader({super.key, required this.tileId, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return const SizedBox(height: 5.0);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () {

            },
            icon: const Icon(Icons.copy)
          ),
          const SizedBox(width: 5.0),
          IconButton(
            icon: const NormalIcon(Icons.delete_outline),
            onPressed: () {
              final event = DeleteTile(tileId: tileId);
              context.read<NotebookBloc>().add(event);
            }
          )
        ]
      )
    );
  }
}

class NoteBlock extends StatefulWidget {
  final Query query;
  final String note;
  final bool readOnly;

  const NoteBlock({super.key, required this.query, required this.note, required this.readOnly});

  @override
  State<NoteBlock> createState() => _NoteBlockState();
}

class _NoteBlockState extends State<NoteBlock> {
  bool _editing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: NormalText(widget.note)
      );
    }

    if (_editing) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 10
          )),
          const SizedBox(width: 5.0),
          IconButton(
            icon: const NormalIcon(Icons.check),
            onPressed: () {
              final event = ReplaceTile(query: widget.query, note: _controller.text);
              context.read<NotebookBloc>().add(event);
              setState(() => _editing = false);
            }
          )
        ]
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: NormalText(widget.note)
        )),
        const SizedBox(width: 8.0),
        IconButton(
          icon: const NormalIcon(Icons.edit_outlined),
          tooltip: "Edit note",
          onPressed: () {
            _controller.text = widget.note;
            setState(() => _editing = true);
          }
        )
      ]
    );
  }
}

class FilterSection extends StatelessWidget {
  final Query query;
  final String note;
  final bool readOnly;

  const FilterSection({super.key, required this.query, required this.note, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const NormalText("filters"),
            if (!readOnly)
              IconButton(
                icon: const NormalIcon(Icons.add),
                onPressed: () {
                  final newQuery = query.copy();
                  final newFilter = NumericFilter(path: "");
                  newQuery.filters.add(newFilter);

                  final event = ReplaceTile(query: newQuery, note: note);
                  context.read<NotebookBloc>().add(event);
                }
              )
          ]),
          for (var i = 0; i < query.filters.length; i++)
            ...[
              const SizedBox(height: 5.0),
              FilterRow(key: ValueKey<int>(i), query: query, note: note, idx: i, readOnly: readOnly)
            ]
        ]
      )
    );
  }
}

class SelectionSection extends StatelessWidget {
  final Query query;
  final String note;
  final bool readOnly;

  const SelectionSection({super.key, required this.query, required this.note, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final paths = query.select;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const NormalText("select"),
            if (!readOnly)
              IconButton(
                icon: const NormalIcon(Icons.add),
                tooltip: "Add path",
                onPressed: () {
                  final newQuery = query.copy();
                  newQuery.select.add("");
                  final event = ReplaceTile(query: newQuery, note: note);
                  context.read<NotebookBloc>().add(event);
                }
              )
          ]),
          for (var i = 0; i < paths.length; i++)
            ...[
              const SizedBox(height: 5.0),
              SelectRow(key: ValueKey<int>(i), query: query, note: note, idx: i, readOnly: readOnly),
            ]
        ]
      )
    );
  }
}

class SelectRow extends StatelessWidget {
  final Query query;
  final String note;
  final int idx;
  final bool readOnly;

  const SelectRow({super.key, required this.query, required this.note, required this.idx, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: NormalText(query.select[idx])
      );
    }

    final bloc = context.read<NotebookBloc>();
    return Row(children: [
      Expanded(child: SyncedTextField(
        text: query.select[idx],
        onChanged: (next) {
          final newQuery = query.copy();
          newQuery.select[idx] = next;
          bloc.add(ReplaceTile(query: newQuery, note: note));
        }
      )),
      IconButton(
        icon: const NormalIcon(Icons.close),
        tooltip: "Remove path",
        onPressed: () {
          final newQuery = query.copy();
          newQuery.select.removeAt(idx);
          bloc.add(ReplaceTile(query: newQuery, note: note));
        }
      )
    ]);
  }
}

class ResultsSection extends StatelessWidget {
  final Query query;

  const ResultsSection({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final results = query.results;
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            NormalText("results"),
            Spacer(),
            NormalText("min · q1 · med · q3 · max")
          ]),
          if (results == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: NormalText("— no results —")
            )
          else
            for (var i = 0; i < results.length; i++)
              ResultsRow(path: query.select[i], results: results[i])

        ]
      )
    );
  }
}

class ResultsRow extends StatelessWidget {
  final String path;
  final QueryResults? results;

  const ResultsRow({super.key, required this.path, required this.results});

  @override
  Widget build(BuildContext context) {
    final summary = results == null
      ? "—"
      : "${results!.min.toStringAsFixed(2)} · ${results!.q1.toStringAsFixed(2)} · ${results!.median.toStringAsFixed(2)} · ${results!.q3.toStringAsFixed(2)} · ${results!.max.toStringAsFixed(2)}";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: NormalText(path, maxLines: 1)),
            const SizedBox(width: 10.0),
            NormalText(summary)
          ]),
          const SizedBox(height: 5.0),
          BoxPlot(result: results)
        ]
      )
    );
  }
}
