import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:forui/forui.dart";
import "package:go_router/go_router.dart";

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

    final location = switch (idx) {
      0 => "/experiments",
      1 => "/analysis",
      2 => "/reference",
      3 => "/settings",
      _ => "/experiments"
    };
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      sidebar: FSidebar(
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
