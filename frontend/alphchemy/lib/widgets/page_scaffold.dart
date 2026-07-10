import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:alphchemy/pages/notebooks_page.dart";
import "package:alphchemy/pages/reference_page.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";

class PageScaffold extends StatelessWidget {
  final int selectedIdx;
  final Widget child;

  const PageScaffold({super.key, required this.selectedIdx, required this.child});

  FSidebarItem _destination(BuildContext context, {required IconData icon, required String label, required int idx}) {
    return FSidebarItem(
      icon: NormalIcon(icon),
      label: NormalText(label),
      selected: idx == selectedIdx,
      onPress: () => _navigate(context, idx)
    );
  }

  void _navigate(BuildContext context, int idx) {
    if (idx == selectedIdx) return;

    Navigator.push(context, MaterialPageRoute(
      builder: (context) => switch (idx) {
        0 => const ExperimentsPage(),
        1 => const NotebooksPage(),
        2 => const ReferencePage(),
        _ => const ExperimentsPage()
      }
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      sidebar: FSidebar(
        footer: const ThemeToggleButton(),
        children: [
          FSidebarGroup(children: [
            _destination(context, icon: Icons.science, label: "Experiments", idx: 0),
            _destination(context, icon: Icons.analytics_outlined, label: "Analysis", idx: 1),
            _destination(context, icon: Icons.article, label: "Reference", idx: 2),
            _destination(context, icon: Icons.settings, label: "Settings", idx: 3)
          ])
        ]
      ),
      child: child
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
        return FButton.icon(
          variant: FButtonVariant.ghost,
          onPress: () => context.read<ThemeBloc>().add(const ToggleTheme()),
          child: NormalIcon(isDark ? Icons.light_mode : Icons.dark_mode)
        );
      }
    );
  }
}
