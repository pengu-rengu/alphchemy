import "package:alphchemy/blocs/generators_bloc.dart";
import "package:alphchemy/pages/home.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:alphchemy/repositories/generator_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

final theme = ThemeData(
  brightness: Brightness.dark,

  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 12, color: Colors.white70),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white30),
    ),
  ),
  checkboxTheme: const CheckboxThemeData(
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final generatorRepo = GeneratorRepository();
  final chatRepo = ChatRepository();
  final generatorsBloc = GeneratorsBloc(repository: generatorRepo);
  generatorsBloc.add(const LoadGenerators());

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<GeneratorRepository>.value(value: generatorRepo),
        RepositoryProvider<ChatRepository>.value(value: chatRepo)
      ],
      child: BlocProvider.value(
        value: generatorsBloc,
        child: MaterialApp(
          theme: theme,
          home: const HomePage()
        )
      )
    )
  );
}
