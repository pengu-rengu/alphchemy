import "dart:ui";

import "package:alphchemy/blocs/param_space_bloc.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/widgets/node_content.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobx/mobx.dart";
import "package:vyuh_node_flow/vyuh_node_flow.dart";

void main() {
  group("NodeContent list resize", () {
    testWidgets("add and remove cycles do not accumulate height", (
      WidgetTester tester
    ) async {
      final node = _buildLogicNetNode([1]);
      await tester.pumpWidget(_buildTestApp(node));
      await _pumpNodeLayout(tester);

      final initialHeight = node.size.value.height;

      await tester.tap(find.byIcon(Icons.add));
      await _pumpNodeLayout(tester);

      final addedHeight = node.size.value.height;
      expect(addedHeight, greaterThan(initialHeight));

      await tester.tap(find.byIcon(Icons.close).last);
      await _pumpNodeLayout(tester);

      final firstCycleHeight = node.size.value.height;
      expect(firstCycleHeight, initialHeight);

      await tester.tap(find.byIcon(Icons.add));
      await _pumpNodeLayout(tester);
      await tester.tap(find.byIcon(Icons.close).last);
      await _pumpNodeLayout(tester);

      expect(node.size.value.height, initialHeight);
    });

    testWidgets("editing a list item keeps node height stable", (
      WidgetTester tester
    ) async {
      final node = _buildLogicNetNode([1, 2]);
      await tester.pumpWidget(_buildTestApp(node));
      await _pumpNodeLayout(tester);

      final initialHeight = node.size.value.height;

      await tester.enterText(find.byType(TextField).first, "42");
      await _pumpNodeLayout(tester);

      expect(node.size.value.height, initialHeight);
    });

    testWidgets("deleting a list item shrinks height to the expected size", (
      WidgetTester tester
    ) async {
      final node = _buildLogicNetNode([1, 2, 3]);
      await tester.pumpWidget(_buildTestApp(node));
      await _pumpNodeLayout(tester);

      final startHeight = node.size.value.height;

      await tester.tap(find.byIcon(Icons.close).last);
      await _pumpNodeLayout(tester);

      final deletedHeight = node.size.value.height;
      final expectedHeight = await _measureNodeHeight(tester, [1, 2]);

      expect(deletedHeight, lessThan(startHeight));
      expect(deletedHeight, closeTo(expectedHeight, 0.001));
    });
  });
}

Future<void> _pumpNodeLayout(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<double> _measureNodeHeight(
  WidgetTester tester,
  List<int> selection
) async {
  final node = _buildLogicNetNode(selection);
  await tester.pumpWidget(_buildTestApp(node));
  await _pumpNodeLayout(tester);
  return node.size.value.height;
}

Node<NodeObject> _buildLogicNetNode(List<int> selection) {
  final data = LogicNet(nodeSelection: selection);
  final id = "logic-net-${selection.join("_")}";
  return Node<NodeObject>(
    id: id,
    type: data.nodeType,
    position: Offset.zero,
    data: data,
    ports: LogicNet.ports(),
    size: const Size(250, 0)
  );
}

Widget _buildTestApp(Node<NodeObject> node) {
  return MaterialApp(
    home: BlocProvider(
      create: (_) => ParamSpaceBloc(),
      child: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: _TestNodeHost(
            key: ValueKey(node.id),
            node: node
          )
        )
      )
    )
  );
}

class _TestNodeHost extends StatefulWidget {
  final Node<NodeObject> node;

  const _TestNodeHost({super.key, required this.node});

  @override
  State<_TestNodeHost> createState() => _TestNodeHostState();
}

class _TestNodeHostState extends State<_TestNodeHost> {
  ReactionDisposer? _disposeReaction;

  @override
  void initState() {
    super.initState();
    _startReaction();
  }

  @override
  void didUpdateWidget(_TestNodeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node == widget.node) return;
    _disposeReaction?.call();
    _startReaction();
  }

  @override
  void dispose() {
    _disposeReaction?.call();
    super.dispose();
  }

  void _startReaction() {
    _disposeReaction = reaction<Size>((_) {
      return widget.node.size.value;
    }, (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.node.size.value;
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Material(
          child: NodeContent(node: widget.node)
        )
      )
    );
  }
}
