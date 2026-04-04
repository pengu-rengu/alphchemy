import "package:alphchemy/widgets/experiment_gen_editor.dart";
import "package:flutter/material.dart";

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text("Home"),
                ),
              ],
              selectedIndex: 0,
            ),
            const VerticalDivider(),
            const Expanded(child: ExperimentGenEditor()),
          ],
        ),
      ),
    );
  }
}
