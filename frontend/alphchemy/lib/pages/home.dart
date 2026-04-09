import "package:alphchemy/pages/chat_page.dart";
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
                  label: Text("Generators")
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat),
                  label: Text("Chat")
                )
              ],
              selectedIndex: 0,
              onDestinationSelected: (index) {
                if (index == 1) _openChat(context);
              }
            ),
            const VerticalDivider(),
            const Expanded(child: GeneratorsPage())
          ]
        )
      )
    );
  }

  static void _openChat(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const ChatPage()
    );
    Navigator.of(context).push(route);
  }
}
