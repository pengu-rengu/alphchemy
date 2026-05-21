import "package:alphchemy/blocs/agents/agent_bloc.dart";
import "package:alphchemy/blocs/agents/agents_bloc.dart";
import "package:alphchemy/widgets/agents/agent_area.dart";
import "package:alphchemy/widgets/agents/agent_sidebar.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AgentsBloc, AgentsState>(
      listenWhen: (prev, next) {
        final prevId = prev is AgentsLoaded ? prev.activeId : null;
        final nextId = next is AgentsLoaded ? next.activeId : null;
        return prevId != nextId;
      },
      listener: (listenerContext, state) {
        final activeId = state is AgentsLoaded ? state.activeId : null;
        final agentBloc = listenerContext.read<AgentBloc>();
        if (activeId == null) {
          agentBloc.add(const DeselectAgent());
        } else {
          agentBloc.add(SubscribeToAgent(id: activeId));
        }
      },
      child: const PageScaffold(
        selectedIdx: 3,
        child: Row(
          children: [
            Expanded(child: AgentArea()),
            VerticalDivider(width: 1),
            SizedBox(width: 300, child: AgentSidebar())
          ]
        )
      )
    );
  }
}
