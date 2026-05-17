import "package:alphchemy/pages/agents_page.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:alphchemy/pages/feature_sets_page.dart";
import "package:alphchemy/pages/results_page.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";

class PageScaffold extends StatelessWidget {
  final int selectedIdx;
  final Widget child;

  const PageScaffold({super.key, required this.selectedIdx, required this.child});

  NavigationRailDestination _destination({required IconData icon, required String label}) {
    return NavigationRailDestination(
      icon: NormalIcon(icon),
      label: NormalText(label),
      padding: const EdgeInsets.symmetric(vertical: 5.0)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          NavigationRail(
            labelType: NavigationRailLabelType.all,
            scrollable: true,
            destinations: [
              _destination(icon: Icons.science, label: "Experiments"),
              _destination(icon: Icons.smart_toy, label: "Agents"),
              _destination(icon: Icons.bar_chart, label: "Results"),
              _destination(icon: Icons.candlestick_chart, label: "Chart"),
              _destination(icon: Icons.code, label: "Scripts"),
              _destination(icon: Icons.search, label: "Scanners"),
              _destination(icon: Icons.analytics_outlined, label: "Analysis"),
              _destination(icon: Icons.article, label: "Reference"),
              _destination(icon: Icons.settings, label: "Settings")
            ],
            selectedIndex: selectedIdx,
            onDestinationSelected: (index) => _openPage(context, index)
          ),
          const VerticalDivider(width: 0.0),
          Expanded(child: child)
        ])
      )
    );
  }

  void _openPage(BuildContext context, int index) {
    if (index == selectedIdx) {
      return;
    }

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
    if (index == 2) {
      return const ResultsPage();
    }
    if (index == 3) {
      return const FeatureSetsPage();
    }
    return const ExperimentsPage();
  }
}
