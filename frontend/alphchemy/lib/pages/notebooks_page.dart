import "package:alphchemy/blocs/notebooks/notebooks_bloc.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/pages/notebook_page.dart";
import "package:alphchemy/utils.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class NotebooksPage extends StatelessWidget {
  const NotebooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotebooksBloc>(
      create: (_) {
        final bloc = NotebooksBloc(client: context.read<SupabaseClient>());
        bloc.add(const LoadNotebooks());
        return bloc;
      },
      child: const PageScaffold(
        selectedIdx: 1,
        child: NotebooksArea()
      )
    );
  }
}

class NotebooksArea extends StatelessWidget {
  const NotebooksArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotebooksBloc, NotebooksState>(
      builder: (context, state) {
        return Column(children: [
          // ignore: prefer_const_constructors
          NotebooksHeader(),
          const FDivider(),
          switch (state) {
            NotebooksInitial() => const LoadingIndicator(),
            NotebooksError() => CenterText(state.message, expanded: true),
            // ignore: prefer_const_constructors
            NotebooksLoaded() => NotebooksList()
          }
        ]);
      }
    );
  }
}

class NotebooksHeader extends StatelessWidget {
  const NotebooksHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotebooksBloc>();

    return Header(
      left: const [LargeText("Notebooks")],
      right: [FButton(
        onPress: () {
          final event = CreateNotebook(
            title: "Untitled",
            onCreated: (id) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => NotebookPage(notebookId: id)
              ));
            }
          );
          bloc.add(event);
        },
        prefix: const InvertedIcon(Icons.add),
        child: const InvertedText("New Notebook")
      )],
      errorMessage: (() {
        final state = bloc.state;
        return state is NotebooksLoaded ? state.errorMessage : null;
      })(),
    );
  }
}

class NotebooksList extends StatelessWidget {
  const NotebooksList({super.key});

  @override
  Widget build(BuildContext context) {
    final summaries = (context.read<NotebooksBloc>().state as NotebooksLoaded).summaries;

    return Expanded(child: Column(
      children: [
        const NotebookColumnHeaders(),
        const FDivider(),
        Expanded(
          child: summaries.isEmpty ? const CenterText("No notebooks yet") : ListView.separated(
            itemCount: summaries.length,
            separatorBuilder: (_, idx) => const FDivider(),
            itemBuilder: (_, idx) => NotebookRow(summary: summaries[idx])
          )
        )
      ]
    ));
  }
}

class NotebookColumnHeaders extends StatelessWidget {
  const NotebookColumnHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      SizedBox(width: 10.0),
      ListCell(value: "Title", flex: 6),
      ListCell(value: "Last Updated", flex: 1),
      ListCell(value: "", flex: 2)
    ]);
  }
}

class NotebookRow extends StatelessWidget {
  final NotebookSummary summary;

  const NotebookRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const SizedBox(width: 10.0),
      ListCell(value: summary.title, flex: 6, alignLeft: true),
      ListCell(value: relativeTime(summary.lastEdited), flex: 1),
      Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => NotebookPage(notebookId: summary.id)
            ));
          },
          child: const NormalIcon(Icons.open_in_new)
        ),
        FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () async {
            final confirmed = await confirmDeleteDialog(context: context, title: summary.title);
            if (!context.mounted || !confirmed) return;

            final event = DeleteNotebook(id: summary.id);
            context.read<NotebooksBloc>().add(event);
          },
          child: const NormalIcon(Icons.delete_outline)
        )
      ]))
    ]);
  }
}
