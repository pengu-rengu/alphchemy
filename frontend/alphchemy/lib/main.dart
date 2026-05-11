import "package:alphchemy/blocs/agent_bloc.dart";
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
  final agentBloc = AgentBloc(client: supabaseClient);
  experimentsBloc.add(const LoadExperiments());
  agentsBloc.add(const SubscribeToAgents());

  runApp(
    RepositoryProvider.value(
      value: supabaseClient,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExperimentsBloc>.value(value: experimentsBloc),
          BlocProvider<AgentsBloc>.value(value: agentsBloc),
          BlocProvider<AgentBloc>.value(value: agentBloc)
        ],
        child: ActiveAgentBridge(
          child: MaterialApp(
            theme: theme,
            home: const ExperimentsPage()
          )
        )
      )
    )
  );
}

class ActiveAgentBridge extends StatelessWidget {
  final Widget child;

  const ActiveAgentBridge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AgentsBloc, AgentsState>(
      listenWhen: _shouldListen,
      listener: _onAgentsChanged,
      child: child
    );
  }

  bool _shouldListen(AgentsState prev, AgentsState next) {
    final prevId = prev is AgentsLoaded ? prev.activeId : null;
    final nextId = next is AgentsLoaded ? next.activeId : null;
    return prevId != nextId;
  }

  void _onAgentsChanged(BuildContext context, AgentsState state) {
    final agentBloc = context.read<AgentBloc>();
    final activeId = state is AgentsLoaded ? state.activeId : null;
    
    if (activeId != null) {
      final event = LoadAgent(id: activeId);
      agentBloc.add(event);
    }
  }
}
