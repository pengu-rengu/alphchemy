import "package:alphchemy/blocs/notebooks/notebook_bloc.dart";
import "package:alphchemy/model/notebook/notebook_summary.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/notebook/notebook_view.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
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
      // ignore: prefer_const_constructors
      child: FScaffold(
        childPad: false,
        child: const NotebookArea()
      )
    );
  }
}

class NotebookArea extends StatelessWidget {
  const NotebookArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotebookBloc, NotebookState>(
      builder: (context, state) {
        return Column(children: [
          // ignore: prefer_const_constructors
          NotebookHeader(),
          const FDivider(),
          switch (state) {
            NotebookInitial() => const LoadingIndicator(),
            NotebookError() => CenterText(state.message, expanded: true),
            // ignore: prefer_const_constructors
            NotebookLoaded() => NotebookContent()
          }
        ]);
      }
    );
  }
}

class NotebookHeader extends StatelessWidget {
  const NotebookHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<NotebookBloc>().state;
    final loaded = state is NotebookLoaded ? state : null;
    final notebook = loaded?.notebook;
    final working = notebook?.status == NotebookStatus.working;

    return Header(
      left: [
        FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () => Navigator.pop(context),
          child: const NormalIcon(Icons.arrow_back)
        ),
        const SizedBox(width: 10.0),
        LargeText(notebook?.title ?? "Notebook"),
        const SizedBox(width: 5.0),
        if (notebook != null) FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () async {
            final newTitle = await renameDialog(context: context, title: notebook.title);
            if (!context.mounted || newTitle == null) return;

            final event = RenameNotebook(title: newTitle);
            context.read<NotebookBloc>().add(event);
          },
          child: const NormalIcon(Icons.edit)
        )
      ],
      right: loaded == null ? [] : [
        StaleIndicator(stale: loaded.stale),
        FButton(
          onPress: working ? null : () => context.read<NotebookBloc>().add(const RequestNotebookData()),
          prefix: InvertedIcon(working ? Icons.hourglass_top : Icons.send),
          child: InvertedText(working ? "Working..." : "Update")
        )
      ],
      errorMessage: loaded?.errorMessage
    );
  }
}

class NotebookContent extends StatelessWidget {

  const NotebookContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: NotebookView(
      notebook: (context.read<NotebookBloc>().state as NotebookLoaded).notebook,
      readOnly: false
    ));
  }
}
