import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/pages/agents_page.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:alphchemy/pages/feature_sets_page.dart";
import "package:alphchemy/pages/notebooks_page.dart";
import "package:alphchemy/pages/reference_page.dart";
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
              //_destination(icon: Icons.code, label: "Scripts"),
              _destination(icon: Icons.article, label: "Reference"),
              _destination(icon: Icons.settings, label: "Settings")
            ],
            selectedIndex: selectedIdx,
            onDestinationSelected: (idx) {
              if (idx == selectedIdx) {
                return;
              }

              Navigator.push(context, MaterialPageRoute(
                builder: (context) => switch (idx) {
                  0 => const ExperimentsPage(),
                  1 => const NotebooksPage(),
                  2 => const FeatureSetsPage(),
                  3 => const AgentsPage(),
                  4 => const ReferencePage(),
                  _ => const ExperimentsPage()
                }
              ));
            },
            trailing: const ThemeToggleButton()
          ),
          const VerticalDivider(width: 0.0),
          Expanded(child: child)
        ])
      )
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, mode) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          icon: NormalIcon(isDark ? Icons.light_mode : Icons.dark_mode),
          tooltip: isDark ? "Light mode" : "Dark mode",
          onPressed: () => context.read<ThemeBloc>().add(const ToggleTheme())
        );
      }
    );
  }
}
