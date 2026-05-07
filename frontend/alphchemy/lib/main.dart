import "package:alphchemy/blocs/chats_bloc.dart";
import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:alphchemy/repositories/experiment_repository.dart";
import "package:alphchemy/repositories/results_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

final theme = ThemeData(
  brightness: Brightness.dark,

  textTheme: const TextTheme(
    //bodyLarge: TextStyle(fontSize: 20, color: Colors.white70),
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

  final experimentRepo = ExperimentRepository();
  final chatRepo = ChatRepository();
  final resultsRepo = ResultsRepository();
  final experimentsBloc = ExperimentsBloc(repository: experimentRepo);
  final chatsBloc = ChatsBloc(repository: chatRepo);
  experimentsBloc.add(const LoadExperiments());
  chatsBloc.add(const LoadChats());

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ExperimentRepository>.value(value: experimentRepo),
        RepositoryProvider<ChatRepository>.value(value: chatRepo),
        RepositoryProvider<ResultsRepository>.value(value: resultsRepo)
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExperimentsBloc>.value(value: experimentsBloc),
          BlocProvider<ChatsBloc>.value(value: chatsBloc)
        ],
        child: MaterialApp(
          theme: theme,
          home: const ExperimentsPage()
        )
      )
    )
  );
}
