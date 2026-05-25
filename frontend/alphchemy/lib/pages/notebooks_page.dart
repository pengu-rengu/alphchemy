import "package:alphchemy/blocs/notebooks/notebooks_bloc.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/pages/notebook_page.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
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
          const NotebooksHeader(),
          const Divider(height: 1),
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
    return Header(
      left: const [LargeText("Notebooks")],
      right: [FilledButton.icon(
        onPressed: () {
          final event = CreateNotebook(
            title: "Untitled",
            onCreated: (id) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => NotebookPage(notebookId: id)
              ));
            }
          );
          context.read<NotebooksBloc>().add(event);
        },
        icon: const InvertedIcon(Icons.add),
        label: const InvertedText("New Notebook")
      )]
    );
  }
}

class NotebooksList extends StatelessWidget {
  const NotebooksList({super.key});

  @override
  Widget build(BuildContext context) {
    final summaries = (context.read<NotebooksBloc>().state as NotebooksLoaded).summaries;
    
    return summaries.isEmpty
      ? const CenterText("No notebooks yet", expanded: true)
      : Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(10.0),
          itemCount: summaries.length,
          itemBuilder: (context, idx) {
            return NotebookCard(summary: summaries[idx]);
          }
        )
      );
  }
}

class NotebookCard extends StatelessWidget {
  final NotebookSummary summary;

  const NotebookCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return PaddedCard(child: Row(children: [
      NormalText(summary.title),
      const Spacer(),
      IconButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NotebookPage(notebookId: summary.id)
          ));
        },
        icon: const NormalIcon(Icons.open_in_new)
      ),
      IconButton(
        onPressed: () async {
          final confirmed = await confirmDeleteDialog(context: context, title: summary.title);
          if (!context.mounted || !confirmed) return;

          final event = DeleteNotebook(id: summary.id);
          context.read<NotebooksBloc>().add(event);
        },
        icon: const NormalIcon(Icons.delete)
      )
    ]));
  }
}
