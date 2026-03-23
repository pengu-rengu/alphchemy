import "package:flutter/material.dart";

class HomePage extends StatelessWidget {

  const HomePage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: SafeArea(child: Row(
        children: [
          NavigationRail(
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home')
              )
            ],
            selectedIndex: 0
          ),
          VerticalDivider(),
          Expanded(child: Column(
            children: [
              Text("zlkjalsdkjflaksdjf")
            ],
          ))
        ]
      ))
    );
  }

  

}