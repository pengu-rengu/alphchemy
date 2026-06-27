import "dart:convert";

import "package:alphchemy/blocs/experiments/editor_bloc.dart";
import "package:alphchemy/main.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:json_editor_flutter/json_editor_flutter.dart";

class ExperimentEditor extends StatelessWidget {
  const ExperimentEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      buildWhen: (previous, current) {
        return previous.jsonText != current.jsonText;
      },
      builder: (context, state) {
        return JsonEditor(
          json: state.jsonText,
          themeColor: Theme.of(context).extension<AppColors>()!.bgColor3,
          onChanged: (value) {
            final event = UpdateExperimentJson(text: jsonEncode(value));
            context.read<EditorBloc>().add(event);
          }
        );
      }
    );
  }
}
