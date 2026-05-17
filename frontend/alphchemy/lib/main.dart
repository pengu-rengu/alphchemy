import "package:alphchemy/blocs/agent_bloc.dart";
import "package:alphchemy/blocs/agents_bloc.dart";
import "package:alphchemy/blocs/experiments_bloc.dart";
import "package:alphchemy/env.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const light1 = Color.fromRGBO(200, 200, 200, 1.0);
const light2 = Color.fromRGBO(160, 160, 160, 1.0);
const dark1 = Color.fromRGBO(40, 40, 40, 1.0);
const dark2 = Color.fromRGBO(30, 30, 30, 1.0);
const dark3 = Color.fromRGBO(70, 70, 70, 1.0);

final theme = ThemeData(
  brightness: Brightness.dark,
  splashFactory: NoSplash.splashFactory,
  hoverColor: light1.withAlpha(10),
  scaffoldBackgroundColor: dark1,
  dialogTheme: const DialogThemeData(
    backgroundColor: dark1,
    shape: Border()
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: dark2,
    indicatorColor: dark3,
    indicatorShape: Border()
  ),
  
  dividerTheme: const DividerThemeData(
    color: dark3
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 20, color: light1),
    displayMedium: TextStyle(fontSize: 12, color: light1),
    labelMedium: TextStyle(fontSize: 12, color: dark1),
    titleMedium: TextStyle(fontSize: 12, color: light1, fontWeight: FontWeight.bold)
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: dark3,
    selectionColor: dark3
  ),
  inputDecorationTheme: const InputDecorationTheme(
    isDense: true,
    contentPadding: EdgeInsets.all(2),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: light2),
      borderRadius: BorderRadius.zero
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: light2),
      borderRadius: BorderRadius.zero
    )
  ),
  segmentedButtonTheme: const SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      backgroundColor: WidgetStateProperty.fromMap({
        WidgetState.selected: light1,
        WidgetState.disabled: dark1
      })
    )
  ),
  checkboxTheme: const CheckboxThemeData(
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  iconButtonTheme: const IconButtonThemeData(
    style: ButtonStyle(visualDensity: VisualDensity.compact)
  ),
  expansionTileTheme: const ExpansionTileThemeData(
    shape: Border(),
    expansionAnimationStyle: AnimationStyle.noAnimation,
    expandedAlignment: AlignmentGeometry.centerLeft,
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    iconColor: light1
  ),
  cardTheme: CardThemeData(
    color: dark2,
    shape: Border.all(color: dark3)
  ),
  filledButtonTheme: const FilledButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      overlayColor: WidgetStatePropertyAll(light2),
      backgroundColor: WidgetStatePropertyAll(light1)
    )
  ),
  dropdownMenuTheme: const DropdownMenuThemeData(
    textStyle: TextStyle(fontSize: 12, color: light1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.all(2),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: light2),
        borderRadius: BorderRadius.zero
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: light2),
        borderRadius: BorderRadius.zero
      )
    ),
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(dark1),
      visualDensity: VisualDensity.compact
    )
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: dark2,
    selectedColor: light1,
    disabledColor: dark2,
    side: BorderSide(color: dark3),
    shape: RoundedRectangleBorder(),
    showCheckmark: false
  ),
  listTileTheme: ListTileThemeData(
    selectedTileColor: light1.withAlpha(50)
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: dark3
  ),
  popupMenuTheme: const PopupMenuThemeData(
    color: dark1
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
      final event = SubscribeToAgent(id: activeId);
      agentBloc.add(event);
    }
  }
}
