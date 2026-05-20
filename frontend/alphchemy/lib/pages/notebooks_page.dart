import "package:alphchemy/blocs/notebooks_bloc.dart";
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
        child: NotebooksBody()
      )
    );
  }
}

class NotebooksBody extends StatelessWidget {
  const NotebooksBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const NotebooksHeader(),
      const Divider(height: 1),
      Expanded(child: BlocBuilder<NotebooksBloc, NotebooksState>(
        builder: (context, state) {
          if (state is NotebooksError) {
            return Center(child: NormalText(state.message));
          }
          if (state is! NotebooksLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return NotebooksList(summaries: state.summaries);
        }
      ))
    ]);
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
  final List<NotebookSummary> summaries;

  const NotebooksList({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Center(child: NormalText("No notebooks yet"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: summaries.length,
      itemBuilder: (context, idx) {
        return NotebookCard(summary: summaries[idx]);
      }
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
