import "package:alphchemy/blocs/notebooks/notebook_bloc.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class NotebookTile extends StatelessWidget {
  final int idx;
  final Query query;
  final String note;
  final bool readOnly;

  const NotebookTile({super.key, required this.idx, required this.query, required this.note, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TileHeader(idx: idx, readOnly: readOnly),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: NoteSection(tileIdx: idx, query: query, note: note, readOnly: readOnly)
          ),
          const Divider(height: 1),
          QuerySection(tileIdx: idx, query: query, note: note, readOnly: readOnly),
          const Divider(height: 1),
          ResultsSection(query: query)
        ]
      )
    );
  }
}

class TileHeader extends StatelessWidget {
  final int idx;
  final bool readOnly;

  const TileHeader({super.key, required this.idx, required this.readOnly});

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
              final event = DeleteTile(idx: idx);
              context.read<NotebookBloc>().add(event);
            }
          )
        ]
      )
    );
  }
}

class NoteSection extends StatefulWidget {
  final int tileIdx;
  final Query query;
  final String note;
  final bool readOnly;

  const NoteSection({super.key, required this.tileIdx, required this.query, required this.note, required this.readOnly});

  @override
  State<NoteSection> createState() => _NoteSectionState();
}

class _NoteSectionState extends State<NoteSection> {
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
          Expanded(child: StyledTextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 10
          )),
          const SizedBox(width: 5.0),
          IconButton(
            icon: const NormalIcon(Icons.check),
            onPressed: () {
              final event = ReplaceTile(idx: widget.tileIdx, query: widget.query, note: _controller.text);
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
        const SizedBox(width: 5.0),
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

class QuerySection extends StatefulWidget {
  final int tileIdx;
  final Query query;
  final String note;
  final bool readOnly;

  const QuerySection({super.key, required this.tileIdx, required this.query, required this.note, required this.readOnly});

  @override
  State<QuerySection> createState() => _QuerySectionState();
}

class _QuerySectionState extends State<QuerySection> {
  bool _editing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query.query);
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
        padding: const EdgeInsets.all(10.0),
        child: NormalText(widget.query.query)
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editing)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BoldText("query"),
                const Spacer(),
                IconButton(
                  icon: const NormalIcon(Icons.check),
                  onPressed: () {
                    final newQuery = Query(query: _controller.text, results: widget.query.results);
                    final event = ReplaceTile(idx: widget.tileIdx, query: newQuery, note: widget.note);
                    context.read<NotebookBloc>().add(event);
                    setState(() => _editing = false);
                  }
                )
              ]
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BoldText("query"),
                const Spacer(),
                IconButton(
                  icon: const NormalIcon(Icons.edit_outlined),
                  tooltip: "Edit query",
                  onPressed: () {
                    _controller.text = widget.query.query;
                    setState(() => _editing = true);
                  }
                )
              ]
            ),
          const SizedBox(height: 5.0),
          if (_editing)
            StyledTextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 12
            )
          else
            NormalText(widget.query.query)
        ]
      )
    );
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
          const NormalText("results"),
          if (results == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: NormalText("— no results —")
            )
          else
            for (final result in results)
              ResultsRow(result: result)
        ]
      )
    );
  }
}

class ResultsRow extends StatelessWidget {
  final QueryResults result;

  const ResultsRow({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    for (final value in result.values) {
      final text = value is double ? value.toStringAsFixed(4) : value.toString();
      parts.add(text);
    }
    final joined = parts.isEmpty ? "—" : parts.join(", ");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NormalText(result.path, maxLines: 1),
          NormalText(joined),
          NormalText("skipped: ${result.skipped}")
        ]
      )
    );
  }
}
