import "package:alphchemy/pages/agents_page.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";

class PageScaffold extends StatelessWidget {
  final int selectedIdx;
  final Widget child;

  const PageScaffold({super.key, required this.selectedIdx, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          NavigationRail(
            destinations: const [
              NavigationRailDestination(
                icon: NormalIcon(Icons.science),
                label: NormalText("Experiments")
              ),
              NavigationRailDestination(
                icon: NormalIcon(Icons.smart_toy),
                label: NormalText("Agents")
              )
            ],
            selectedIndex: selectedIdx,
            onDestinationSelected: (index) => _openPage(context, index)
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child)
        ])
      )
    );
  }

  void _openPage(BuildContext context, int index) {
    final route = MaterialPageRoute<void>(
      builder: (routeContext) => _buildPage(index)
    );
    final navigator = Navigator.of(context);
    navigator.push(route);
  }

  Widget _buildPage(int index) {
    if (index == 0) {
      return const ExperimentsPage();
    }
    if (index == 1) {
      return const AgentsPage();
    }
    return const ExperimentsPage();
  }
}
