import "package:alphchemy/blocs/notebook_bloc.dart";
import "package:alphchemy/model/notebook/filter.dart";
import "package:alphchemy/model/notebook/query.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class FilterRow extends StatelessWidget {
  final Query query;
  final String note;
  final int idx;

  const FilterRow({super.key, required this.query, required this.note, required this.idx});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotebookBloc>();
    final filter = query.filters[idx];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DropdownMenu<String>(
          initialSelection: filter.type,
          requestFocusOnTap: false,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: "numeric", label: "numeric"),
            DropdownMenuEntry(value: "string", label: "string"),
            DropdownMenuEntry(value: "bool", label: "bool")
          ],
          onSelected: (type) {
            if (type == null || type == filter.type) return;
            final path = filter.path;
            final next = switch (type) {
              "numeric" => NumericFilter(path: path),
              "string" => StringFilter(path: path, eq: ""),
              "bool" => BoolFilter(path: path, eq: true),
              _ => StringFilter(path: path, eq: "")
            };
            final newQuery = query.copy();
            newQuery.filters[idx] = next;

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        ),
        const SizedBox(width: 5.0),
        Expanded(
          flex: 2,
          child: SyncedTextField(
            text: filter.path,
            onChanged: (next) {
              final newQuery = query.copy();
              newQuery.filters[idx].path = next;

              final event = ReplaceTile(query: newQuery, note: note);
              bloc.add(event);
            }
          )
        ),
        const SizedBox(width: 5.0),
        Expanded(
          flex: 3,
          child: switch (filter) {
            NumericFilter() => NumericFilterOperator(query: query, note: note, idx: idx),
            StringFilter() => StringFilterOperator(query: query, note: note, idx: idx),
            BoolFilter() => BoolFilterOperator(query: query, note: note, idx: idx)
          }
        ),
        IconButton(
          icon: const NormalIcon(Icons.close),
          tooltip: "Remove filter",
          onPressed: () {
            final newQuery = query.copy();
            newQuery.filters.removeAt(idx);

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        )
      ]
    );
  }
}

class NumericFilterOperator extends StatelessWidget {
  final Query query;
  final String note;
  final int idx;

  const NumericFilterOperator({super.key, required this.query, required this.note, required this.idx});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotebookBloc>();
    final filter = query.filters[idx] as NumericFilter;
    return Row(
      children: [
        const NormalText("="),
        const SizedBox(width: 5.0),
        Expanded(child: SyncedTextField(
          text: filter.eq?.toString() ?? "",
          onChanged: (text) {
            final parsed = text.isEmpty ? null : double.tryParse(text);
            if (text.isNotEmpty && parsed == null) return;

            final newQuery = query.copy();
            (newQuery.filters[idx] as NumericFilter).eq = parsed;

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        )),
        const SizedBox(width: 5.0),
        const NormalText("≥"),
        const SizedBox(width: 5.0),
        Expanded(child: SyncedTextField(
          text: filter.gte?.toString() ?? "",
          onChanged: (text) {
            final parsed = text.isEmpty ? null : double.tryParse(text);
            if (text.isNotEmpty && parsed == null) return;

            final newQuery = query.copy();
            (newQuery.filters[idx] as NumericFilter).gte = parsed;

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        )),
        const SizedBox(width: 5.0),
        const NormalText("≤"),
        const SizedBox(width: 5.0),
        Expanded(child: SyncedTextField(
          text: filter.lte?.toString() ?? "",
          onChanged: (text) {
            final parsed = text.isEmpty ? null : double.tryParse(text);
            if (text.isNotEmpty && parsed == null) return;

            final newQuery = query.copy();
            (newQuery.filters[idx] as NumericFilter).lte = parsed;

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        ))
      ]
    );
  }
}

class StringFilterOperator extends StatelessWidget {
  final Query query;
  final String note;
  final int idx;

  const StringFilterOperator({super.key, required this.query, required this.note, required this.idx});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotebookBloc>();

    return Row(
      children: [
        const NormalText("="),
        const SizedBox(width: 5.0),
        Expanded(child: SyncedTextField(
          text: (query.filters[idx] as StringFilter).eq,
          onChanged: (next) {
            final newQuery = query.copy();
            (newQuery.filters[idx] as StringFilter).eq = next;

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        ))
      ]
    );
  }
}

class BoolFilterOperator extends StatelessWidget {
  final Query query;
  final String note;
  final int idx;

  const BoolFilterOperator({super.key, required this.query, required this.note, required this.idx});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotebookBloc>();

    return Row(
      children: [
        const NormalText("="),
        const SizedBox(width: 5.0),
        Expanded(child: DropdownMenu<bool>(
          expandedInsets: EdgeInsets.zero,
          initialSelection: (query.filters[idx] as BoolFilter).eq,
          requestFocusOnTap: false,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: true, label: "true"),
            DropdownMenuEntry(value: false, label: "false")
          ],
          onSelected: (value) {
            if (value == null) return;

            final newQuery = query.copy();
            (newQuery.filters[idx] as BoolFilter).eq = value;

            final event = ReplaceTile(query: newQuery, note: note);
            bloc.add(event);
          }
        ))
      ]
    );
  }
}
