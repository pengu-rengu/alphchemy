import 'package:alphchemy/blocs/experiment_bloc.dart';
import 'package:alphchemy/blocs/node_editor_bloc.dart';
import "package:alphchemy/objects/mock_data.dart";
import 'package:alphchemy/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final editorBloc = NodeEditorBloc();
  editorBloc.add(LoadGraphFromJson(json: mockExperimentGenJson));

  runApp(MaterialApp(
    theme: ThemeData(
      brightness: Brightness.dark
    ),
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ExperimentBloc()),
        BlocProvider.value(value: editorBloc)
      ],
      child: HomePage()
    )
  ));
}
