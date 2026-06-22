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
          selectedIdx: 2,
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

        final agentBloc = listenerContext.read<AgentBloc>();

        final activeId = state.activeId;
        if (activeId == null) {
          agentBloc.add(const DeselectAgent());
          return;
        }

        final event = SubscribeToAgent(id: activeId);
        agentBloc.add(event);
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
          // ignore: prefer_const_constructors
          AgentsLoaded() => AgentsContent()
        };
      }
    );
  }
}

class AgentsContent extends StatelessWidget {
  const AgentsContent({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_constructors
    return Row(
      // ignore: prefer_const_literals_to_create_immutables
      children: [
        // ignore: prefer_const_constructors
        Expanded(child: AgentArea()),
        const VerticalDivider(width: 1),
        // ignore: prefer_const_constructors
        SizedBox(width: 300, child: AgentSidebar())
      ]
    );
  }
}
