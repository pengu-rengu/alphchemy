import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/objects/actions.dart";
import "package:alphchemy/objects/network.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:alphchemy/widgets/param_sidebar.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("NodeObject field parsing", () {
    test("parseIntList drops invalid tokens", () {
      expect(NodeObject.parseIntList("1, nope, 3"), [1, 3]);
    });

    test("parseStringList keeps valid tokens", () {
      final data = MetaAction();
      data.updateField("subActions", "buy, sell, hold");
      expect(data.subActions, ["buy", "sell", "hold"]);
    });

    test("InputNode featId round-trips nullable strings", () {
      final data = InputNode();
      data.updateField("featId", "feat_a");
      expect(data.featId, "feat_a");
      expect(data.formatField("featId"), "feat_a");

      data.updateField("featId", "");
      expect(data.featId, isNull);
      expect(data.formatField("featId"), "");
    });

    test("BranchNode featId round-trips nullable strings", () {
      final data = BranchNode();
      data.updateField("featId", "feat_b");
      expect(data.featId, "feat_b");
      expect(data.formatField("featId"), "feat_b");
    });

    test("Gate.parseList drops invalid gate tokens", () {
      final data = LogicActions();
      data.updateField("allowedGates", "and, invalid, xor");
      expect(data.allowedGates, [Gate.and, Gate.xor]);
    });

    test("formatField round-trips int list", () {
      expect(NodeObject.formatList([1, 2, 3]), "1, 2, 3");
    });

    test("formatField round-trips gate list", () {
      final data = LogicActions();
      data.updateField("allowedGates", "and, xor");
      expect(data.formatField("allowedGates"), "and, xor");
    });

    test("featOrder round-trips string lists", () {
      final data = LogicActions();
      data.updateField("featOrder", "feat_a, feat_b");
      expect(data.featOrder, ["feat_a", "feat_b"]);
      expect(data.formatField("featOrder"), "feat_a, feat_b");
    });
  });

  group("ParamValuesRow csv editing", () {
    testWidgets("parses grouped int list params", (WidgetTester tester) async {
      final bloc = TestEditorBloc();
      addTearDown(() async {
        await bloc.close();
      });

      bloc.loadParams({
        "choices": Param(
          name: "choices",
          type: ParamType.intListType,
          values: const [],
        ),
      });

      await tester.pumpWidget(_buildParamValuesApp(bloc, "choices"));
      await tester.enterText(find.byType(TextField), "1, nope, 3; 4, 5");
      await tester.pump();

      final param = bloc.state.params["choices"]!;
      expect(param.values, [
        [1, 3],
        [4, 5],
      ]);
      expect(_textFieldValue(tester), "1, 3; 4, 5");
    });

    testWidgets("parses grouped string list params", (
      WidgetTester tester,
    ) async {
      final bloc = TestEditorBloc();
      addTearDown(() async {
        await bloc.close();
      });

      bloc.loadParams({
        "actions": Param(
          name: "actions",
          type: ParamType.stringListType,
          values: const [],
        ),
      });

      await tester.pumpWidget(_buildParamValuesApp(bloc, "actions"));
      await tester.enterText(find.byType(TextField), "buy, sell; hold");
      await tester.pump();

      final param = bloc.state.params["actions"]!;
      expect(param.values, [
        ["buy", "sell"],
        ["hold"],
      ]);
      expect(_textFieldValue(tester), "buy, sell; hold");
    });
  });
}

class TestEditorBloc extends EditorBloc {
  void loadParams(Map<String, Param> params) {
    emit(EditorInitial(params: params));
  }
}

MaterialApp _buildParamValuesApp(TestEditorBloc bloc, String paramName) {
  return MaterialApp(
    home: BlocProvider<EditorBloc>.value(
      value: bloc,
      child: Scaffold(
        body: BlocBuilder<EditorBloc, EditorState>(
          builder: (context, state) {
            final param = state.params[paramName]!;
            return ParamValuesRow(param: param);
          },
        ),
      ),
    ),
  );
}

String _textFieldValue(WidgetTester tester) {
  final textField = tester.widget<TextField>(find.byType(TextField));
  return textField.controller!.text;
}
