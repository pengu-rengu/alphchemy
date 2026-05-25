import "package:alphchemy/blocs/agents/agent_bloc.dart";
import "package:alphchemy/blocs/agents/agents_bloc.dart";
import "package:alphchemy/widgets/agents/agent_area.dart";
import "package:alphchemy/widgets/agents/agent_sidebar.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AgentsBloc>(
          create: (_) {
            final bloc = AgentsBloc(client: client);
            bloc.add(const SubscribeToAgents());
            return bloc;
          }
        ),
        BlocProvider<AgentBloc>(create: (_) => AgentBloc(client: client))
      ],
      child: const AgentsListener(
        child: PageScaffold(
          selectedIdx: 3,
          child: AgentsArea()
        )
      )
    );
  }
}

class AgentsListener extends StatelessWidget {
  final Widget child;

  const AgentsListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AgentsBloc, AgentsState>(
      listenWhen: (prev, next) {
        final prevId = prev is AgentsLoaded ? prev.activeId : null;
        final nextId = next is AgentsLoaded ? next.activeId : null;
        return prevId != nextId;
      },
      listener: (listenerContext, state) {
        if (state is! AgentsLoaded) return;

        final activeId = state.activeId;
        if (activeId == null) return;

        final agentBloc = listenerContext.read<AgentBloc>();
        agentBloc.add(SubscribeToAgent(id: activeId));
      },
      child: child
    );
  }
}

class AgentsArea extends StatelessWidget {
  const AgentsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentsBloc, AgentsState>(
      builder: (context, state) {
        return switch (state) {
          AgentsInitial() => const Center(child: CircularProgressIndicator()),
          AgentsError() => CenterText(state.message),
          AgentsLoaded() => const Row(
            children: [
              Expanded(child: AgentArea()),
              VerticalDivider(width: 1),
              SizedBox(width: 300, child: AgentSidebar())
            ]
          )
        };
      }
    );
  }
}
