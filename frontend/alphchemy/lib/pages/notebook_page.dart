import "package:alphchemy/blocs/notebook_bloc.dart";
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
    // ignore: prefer_const_constructors, prefer_const_literals_to_create_immutables
    return Column(children: [
      // ignore: prefer_const_constructors
      NotebookHeader(),
      const Divider(height: 1),
      // ignore: prefer_const_constructors
      Expanded(child: NotebookView())
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

    return Header(
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
        ),
       
      ],
      right: [
        // ignore: prefer_const_constructors
        StaleIndicator(),
        FilledButton.icon(
          onPressed: (working || !state.stale) ? null : () => context.read<NotebookBloc>().add(const SaveNotebook()),
          icon: const InvertedIcon(Icons.save),
          label: const InvertedText("Save")
        ),
        const SizedBox(width: 5.0),
        FilledButton.icon(
          onPressed: working ? null : () => context.read<NotebookBloc>().add(const RequestNotebookData()),
          icon: InvertedIcon(working ? Icons.hourglass_top : Icons.send),
          label: InvertedText(working ? "Working..." : "Request Data")
        )
      ]
    );
  }
}

class StaleIndicator extends StatelessWidget {
  const StaleIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return (context.read<NotebookBloc>().state as NotebookLoaded).stale ? Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.0,
          height: 10.0,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle
          )
        ),
        const SizedBox(width: 5.0),
        const NormalText("stale"),
        const SizedBox(width: 10.0)
      ]
    ) : const SizedBox.shrink();
  }
}
