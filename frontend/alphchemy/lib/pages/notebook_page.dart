import "package:alphchemy/blocs/notebooks/notebook_bloc.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/notebook/notebook_view.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class NotebookPage extends StatelessWidget {
  final int notebookId;

  const NotebookPage({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotebookBloc>(
      create: (_) {
        final client = context.read<SupabaseClient>();
        final bloc = NotebookBloc(client: client);

        final event = SubscribeToNotebook(id: notebookId);
        bloc.add(event);
        return bloc;
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<NotebookBloc, NotebookState>(
            builder: (context, state) {
              if (state is NotebookError) {
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
              if (state is NotebookLoaded) {
                // ignore: prefer_const_constructors
                return NotebookArea();
              }
              return const Center(child: CircularProgressIndicator());
            }
          )
        )
      )
    );
  }
}

class NotebookArea extends StatelessWidget {
  const NotebookArea({super.key});

  @override
  Widget build(BuildContext context) {
    final notebook = (context.read<NotebookBloc>().state as NotebookLoaded).notebook;
    return Column(children: [
      // ignore: prefer_const_constructors
      NotebookHeader(),
      const Divider(height: 1),
      Expanded(child: NotebookView(notebook: notebook, readOnly: false))
    ]);
  }
}

class NotebookHeader extends StatelessWidget {
  const NotebookHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<NotebookBloc>().state as NotebookLoaded;
    final notebook = state.notebook;
    final working = notebook.status == NotebookStatus.working;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Header(
          left: [
            IconButton(
              icon: const NormalIcon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop()
            ),
            const SizedBox(width: 10.0),
            LargeText(notebook.title),
            const SizedBox(width: 5.0),
            IconButton(
              icon: const NormalIcon(Icons.edit),
              onPressed: () async {
                final newTitle = await renameDialog(context: context, title: notebook.title);
                if (!context.mounted || newTitle == null) return;

                final event = RenameNotebook(title: newTitle);
                context.read<NotebookBloc>().add(event);
              }
            )
          ],
          right: [
            StaleIndicator(stale: state.stale),
            FilledButton.icon(
              onPressed: working ? null : () => context.read<NotebookBloc>().add(const RequestNotebookData()),
              icon: InvertedIcon(working ? Icons.hourglass_top : Icons.send),
              label: InvertedText(working ? "Working..." : "Update")
            )
          ]
        ),
        if (state.errorMessage != null) ErrorBanner(message: state.errorMessage!)
      ]
    );
  }
}
