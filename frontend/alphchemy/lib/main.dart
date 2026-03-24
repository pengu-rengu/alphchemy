import 'package:alphchemy/blocs/experiment_bloc.dart';
import 'package:alphchemy/blocs/experiment_generator_bloc.dart';
import 'package:alphchemy/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(MaterialApp(
    theme: ThemeData(
      brightness: Brightness.dark
    ),
    home: MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ExperimentBloc()),
        BlocProvider(create: (context) => ExperimentGeneratorBloc())
      ],
      child: HomePage()
    )
  ));
}
