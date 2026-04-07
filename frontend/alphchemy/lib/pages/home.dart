import "package:alphchemy/pages/generators_page.dart";
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
                  icon: Icon(Icons.auto_awesome),
                  label: Text("Generators"),
                ),
              ],
              selectedIndex: 0,
            ),
            const VerticalDivider(),
            const Expanded(child: GeneratorsPage()),
          ],
        ),
      ),
    );
  }
}
