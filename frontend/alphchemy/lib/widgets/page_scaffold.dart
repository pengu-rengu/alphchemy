import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/pages/agents_page.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:alphchemy/pages/feature_sets_page.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

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
              _destination(icon: Icons.analytics_outlined, label: "Analysis"),
              _destination(icon: Icons.dataset, label: "Feature Sets"),
              _destination(icon: Icons.smart_toy, label: "Agents"),
              _destination(icon: Icons.code, label: "Scripts"),
              _destination(icon: Icons.article, label: "Reference"),
              _destination(icon: Icons.settings, label: "Settings")
            ],
            selectedIndex: selectedIdx,
            onDestinationSelected: (index) => _openPage(context, index),
            trailing: const ThemeToggleButton()
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
    if (index == 2) {
      return const FeatureSetsPage();
    }
    if (index == 3) {
      return const AgentsPage();
    }
    return const ExperimentsPage();
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, mode) {
        final isDark = mode == ThemeMode.dark;
        final icon = isDark ? Icons.light_mode : Icons.dark_mode;
        return IconButton(
          icon: NormalIcon(icon),
          tooltip: isDark ? "Light mode" : "Dark mode",
          onPressed: () => context.read<ThemeBloc>().add(const ToggleTheme())
        );
      }
    );
  }
}
