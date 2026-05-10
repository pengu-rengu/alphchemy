import "package:alphchemy/blocs/agents_bloc.dart";
import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:alphchemy/env.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

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
  iconButtonTheme: const IconButtonThemeData(
    style: ButtonStyle(
      visualDensity: VisualDensity.compact
    )
  ),
  iconTheme: const IconThemeData(
    color: Colors.white70
  ),
  
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey
  );

  final supabaseClient = Supabase.instance.client;
  final experimentsBloc = ExperimentsBloc(client: supabaseClient);
  final agentsBloc = AgentsBloc(client: supabaseClient);
  experimentsBloc.add(const LoadExperiments());
  agentsBloc.add(const LoadAgents());

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SupabaseClient>.value(value: supabaseClient)
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExperimentsBloc>.value(value: experimentsBloc),
          BlocProvider<AgentsBloc>.value(value: agentsBloc)
        ],
        child: MaterialApp(
          theme: theme,
          home: const ExperimentsPage()
        )
      )
    )
  );
}
