import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/generators_bloc.dart";
import "package:alphchemy/blocs/chats_bloc.dart";
import "package:alphchemy/model/generator/experiment.dart";
import "package:alphchemy/model/generator_data.dart";
import "package:alphchemy/model/generator_summary.dart";
import "package:alphchemy/pages/chat_page.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/pages/generators_page.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:alphchemy/repositories/generator_repository.dart";
import "package:alphchemy/widgets/editor/experiment_gen_editor.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";

class TrackingGeneratorRepository extends GeneratorRepository {
  int loadAllCount = 0;

  @override
  Future<List<GeneratorSummary>> loadAll() async {
    loadAllCount += 1;
    return super.loadAll();
  }
}

Widget buildGeneratorsPageApp({
  required GeneratorRepository repository,
  required GeneratorsBloc bloc,
  ChatRepository? chatRepository,
  ChatsBloc? chatsBloc
}) {
  Widget child = const MaterialApp(home: GeneratorsPage());
  child = BlocProvider<GeneratorsBloc>.value(value: bloc, child: child);

  if (chatsBloc != null) {
    child = BlocProvider<ChatsBloc>.value(value: chatsBloc, child: child);
  }

  if (chatRepository != null) {
    child = RepositoryProvider<ChatRepository>.value(
      value: chatRepository,
      child: child
    );
  }

  return RepositoryProvider<GeneratorRepository>.value(
    value: repository,
    child: child
  );
}

Future<void> clearGenerators(GeneratorRepository repository) async {
  final summaries = await repository.loadAll();
  for (final summary in summaries) {
    await repository.delete(summary.id);
  }
}

Future<void> seedGenerator({
  required GeneratorRepository repository,
  required String id,
  required String title
}) async {
  final data = GeneratorData.blank(title);
  await repository.save(id, data);
}

Future<void> loadGeneratorsPage(
  WidgetTester tester, {
  required GeneratorRepository repository,
  required GeneratorsBloc bloc,
  ChatRepository? chatRepository,
  ChatsBloc? chatsBloc
}) async {
  bloc.add(const LoadGenerators());
  await tester.pumpWidget(
    buildGeneratorsPageApp(
      repository: repository,
      bloc: bloc,
      chatRepository: chatRepository,
      chatsBloc: chatsBloc
    )
  );
  await tester.pumpAndSettle();
}

Future<void> closeEditor(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("GeneratorsPage opens the editor from a generator tile", (
    tester
  ) async {
    final repository = GeneratorRepository();
    await clearGenerators(repository);
    await seedGenerator(repository: repository, id: "gen_1", title: "Alpha");

    final bloc = GeneratorsBloc(repository: repository);
    addTearDown(bloc.close);

    await loadGeneratorsPage(tester, repository: repository, bloc: bloc);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

    expect(rail.selectedIndex, 0);
    await tester.tap(find.widgetWithText(ListTile, "Alpha"));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);
  });

  testWidgets("GeneratorsPage navigation opens ChatPage", (tester) async {
    final repository = GeneratorRepository();
    final chatRepository = ChatRepository();
    final bloc = GeneratorsBloc(repository: repository);
    final chatsBloc = ChatsBloc(repository: chatRepository);
    addTearDown(bloc.close);
    addTearDown(chatsBloc.close);
    chatsBloc.add(const LoadChats());

    await loadGeneratorsPage(
      tester,
      repository: repository,
      bloc: bloc,
      chatRepository: chatRepository,
      chatsBloc: chatsBloc
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat));
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));

    expect(rail.selectedIndex, 1);
    expect(find.byType(ChatPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(GeneratorsPage), findsOneWidget);
  });

  testWidgets("GeneratorsPage creates a generator and reloads it after pop", (
    tester
  ) async {
    final repository = GeneratorRepository();
    await clearGenerators(repository);

    final bloc = GeneratorsBloc(repository: repository);
    addTearDown(bloc.close);

    await loadGeneratorsPage(tester, repository: repository, bloc: bloc);

    await tester.tap(find.widgetWithText(FilledButton, "New Generator"));
    await tester.pumpAndSettle();

    expect(find.byType(EditorPage), findsOneWidget);

    await closeEditor(tester);

    expect(find.widgetWithText(ListTile, "Untitled"), findsOneWidget);
  });

  testWidgets("GeneratorsPage confirms deletions before removing a tile", (
    tester
  ) async {
    final repository = GeneratorRepository();
    await clearGenerators(repository);
    await seedGenerator(
      repository: repository,
      id: "gen_1",
      title: "Delete Me"
    );

    final bloc = GeneratorsBloc(repository: repository);
    addTearDown(bloc.close);

    await loadGeneratorsPage(tester, repository: repository, bloc: bloc);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text("Delete Generator"), findsOneWidget);
    expect(find.text("Delete \"Delete Me\"?"), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, "Cancel"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, "Delete Me"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, "Delete"));
    await tester.pumpAndSettle();

    expect(find.text("No generators yet"), findsOneWidget);
    expect(find.text("Delete Me"), findsNothing);
  });

  testWidgets("GeneratorsPage reloads saved titles after the editor closes", (
    tester
  ) async {
    final repository = TrackingGeneratorRepository();
    await clearGenerators(repository);
    await seedGenerator(repository: repository, id: "gen_1", title: "Draft");

    final bloc = GeneratorsBloc(repository: repository);
    addTearDown(bloc.close);

    await loadGeneratorsPage(tester, repository: repository, bloc: bloc);

    await tester.tap(find.widgetWithText(ListTile, "Draft"));
    await tester.pumpAndSettle();

    final editorElement = tester.element(find.byType(ExperimentGenEditor));
    final editorBloc = BlocProvider.of<EditorBloc>(editorElement);
    final loadedState = editorBloc.state as EditorLoaded;
    final experimentNode = loadedState.controller.nodes.values.firstWhere((
      node
    ) {
      return node.data is ExperimentGenerator;
    });
    final experimentData = experimentNode.data as ExperimentGenerator;
    experimentData.title = "Retitled";

    final countBeforeClose = repository.loadAllCount;
    await closeEditor(tester);

    expect(repository.loadAllCount, countBeforeClose + 1);
    expect(find.widgetWithText(ListTile, "Retitled"), findsOneWidget);
  });
}
