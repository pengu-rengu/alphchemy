import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/widgets/experiment_tree.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ExperimentEditor extends StatelessWidget {
  const ExperimentEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      buildWhen: (previous, current) {
        return previous.treeVersion != current.treeVersion;
      },
      builder: (context, state) {
        // IMPOTANT NOTE TO CODEX AND CLAUDE: DO NOT ADD CONST MODIFIERS HERE
        // ignore: prefer_const_constructors
        return Padding(
          padding: const EdgeInsets.all(10.0),
          // ignore: prefer_const_constructors
          child: ExperimentTree(tree: state.tree, readOnly: false)
        );
      }
    );
  }
}
