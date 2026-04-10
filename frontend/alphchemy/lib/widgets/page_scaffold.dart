import "package:alphchemy/pages/chat_page.dart";
import "package:alphchemy/pages/generators_page.dart";
import "package:flutter/material.dart";

class PageScaffold extends StatelessWidget {
  final int selectedIdx;
  final Widget child;

  const PageScaffold({
    super.key,
    required this.selectedIdx,
    required this.child
  });

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
                  label: Text("Chats")
                )
              ],
              selectedIndex: selectedIdx,
              onDestinationSelected: (idx) => _openPage(context, idx)
            ),
            const VerticalDivider(),
            Expanded(child: child)
          ]
        )
      )
    );
  }

  void _openPage(BuildContext context, int idx) {
    final route = MaterialPageRoute<void>(
      builder: (_) => _buildPage(idx)
    );
    final navigator = Navigator.of(context);
    navigator.push(route);
  }

  Widget _buildPage(int idx) {
    if (idx == 0) {
      return const GeneratorsPage();
    }
    return const ChatPage();
  }
}
