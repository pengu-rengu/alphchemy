import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/model/generator_data.dart";
import "package:alphchemy/repositories/generator_repository.dart";
import "package:alphchemy/widgets/experiment_gen_editor.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class EditorPage extends StatelessWidget {
  final String generatorId;
  final GeneratorRepository repository;

  const EditorPage({
    super.key,
    required this.generatorId,
    required this.repository
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      lazy: false,
      create: (context) {
        final bloc = EditorBloc();
        repository.load(generatorId).then((data) {
          bloc.add(LoadGraphFromJson(json: data.toJson()));
        });
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
            appBar: AppBar(
              title: const Text("Editor")
            ),
            body: const ExperimentGenEditor()
          )
        )
      )
    );
  }

  void _saveAndPop(BuildContext context) {
    final bloc = context.read<EditorBloc>();
    try {
      final data = GeneratorData.fromJson(bloc.exportToJson());
      repository.save(generatorId, data).then((_) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
      });
    } catch (_) {
      Navigator.of(context).pop();
    }
  }
}
