import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/model/experiment_data.dart";
import "package:alphchemy/repositories/experiment_repository.dart";
import "package:alphchemy/widgets/editor/experiment_editor.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class EditorPage extends StatelessWidget {
  final String experimentId;
  final ExperimentRepository repository;

  const EditorPage({
    super.key,
    required this.experimentId,
    required this.repository
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      lazy: false,
      create: (context) {
        final bloc = EditorBloc();
        _loadEditor(bloc);
        return bloc;
      },
      child: Builder(
        builder: (innerContext) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _saveAndPop(innerContext);
          },
          child: Scaffold(
            appBar: EditorAppBar(
              onBack: () {
                _saveAndPop(innerContext);
              }
            ),
            body: const ExperimentEditor()
          )
        )
      )
    );
  }

  Future<void> _loadEditor(EditorBloc bloc) async {
    final data = await repository.load(experimentId);
    final event = LoadTreeFromJson(json: data.toJson());
    bloc.add(event);
  }

  Future<void> _saveAndPop(BuildContext context) async {
    final bloc = context.read<EditorBloc>();
    try {
      final data = ExperimentData(experiment: bloc.exportToJson());
      await repository.save(experimentId, data);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      Navigator.of(context).pop();
    }
  }
}

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;

  const EditorAppBar({
    super.key,
    required this.onBack
  });

  @override
  Size get preferredSize {
    return const Size.fromHeight(kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: "Back",
        onPressed: onBack
      ),
      title: const Text("Editor")
    );
  }
}
