import "package:alphchemy/blocs/chat_bloc.dart";
import "package:alphchemy/model/chat_data.dart";
import "package:alphchemy/model/chat_summary.dart";
import "package:alphchemy/pages/chat_page.dart";
import "package:alphchemy/repositories/chat_repository.dart";
import "package:alphchemy/widgets/chat_area.dart";
import "package:alphchemy/widgets/chat_sidebar.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";

class TestChatBloc extends ChatBloc {
  TestChatBloc({required ChatState initialState})
      : super(repository: ChatRepository()) {
    emit(initialState);
  }
}

class TrackingChatRepository extends ChatRepository {
  int loadAllCount = 0;

  @override
  Future<List<ChatSummary>> loadSummaries() async {
    loadAllCount += 1;
    return super.loadSummaries();
  }
}

Future<void> seedChat({
  required ChatRepository repository,
  required String id,
  required String prompt
}) async {
  await repository.saveChat(id, ChatData.blank());
  await repository.sendMessage(id, prompt);
}

ChatMessage buildMessage({
  required String id,
  required String role,
  required String content
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    createdAt: DateTime(2024, 1, 1)
  );
}

Widget buildChatAreaApp({required ChatBloc chatBloc}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<ChatBloc>.value(
        value: chatBloc,
        child: const ChatArea()
      )
    )
  );
}

Widget buildChatPageApp({required ChatRepository repository}) {
  return MaterialApp(
    home: RepositoryProvider<ChatRepository>.value(
      value: repository,
      child: const ChatPage()
    )
  );
}

Future<void> createChat(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, "New Chat"));
  await tester.pumpAndSettle();
}

Future<void> sendMessage(WidgetTester tester, String content) async {
  await tester.enterText(find.byType(TextField), content);
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("ChatArea shows the initial prompt", (tester) async {
    final chatBloc = TestChatBloc(initialState: const ChatInitial());
    addTearDown(chatBloc.close);

    await tester.pumpWidget(buildChatAreaApp(chatBloc: chatBloc));

    expect(find.text("Select or create a chat"), findsOneWidget);
  });

  testWidgets("ChatArea shows chat errors", (tester) async {
    final chatBloc = TestChatBloc(
      initialState: const ChatError(message: "failed to load")
    );
    addTearDown(chatBloc.close);

    await tester.pumpWidget(buildChatAreaApp(chatBloc: chatBloc));

    expect(find.text("failed to load"), findsOneWidget);
  });

  testWidgets("ChatArea renders loaded messages and enabled input", (tester) async {
    final chatBloc = TestChatBloc(
      initialState: ChatLoaded(
        chatId: "chat_1",
        messages: [
          buildMessage(id: "1", role: "user", content: "first"),
          buildMessage(id: "2", role: "assistant", content: "second")
        ]
      )
    );
    addTearDown(chatBloc.close);

    await tester.pumpWidget(buildChatAreaApp(chatBloc: chatBloc));

    final messageWidgets = tester.widgetList<SelectableText>(
      find.byType(SelectableText)
    );
    final messageTexts = messageWidgets.map((widget) {
      return widget.data;
    }).toList();
    final input = tester.widget<TextField>(find.byType(TextField));

    expect(messageTexts, ["second", "first"]);
    expect(input.enabled, true);
  });

  testWidgets("ChatArea keeps messages visible and disables input while sending", (tester) async {
    final chatBloc = TestChatBloc(
      initialState: ChatSending(
        chatId: "chat_1",
        messages: [
          buildMessage(id: "1", role: "user", content: "pending")
        ]
      )
    );
    addTearDown(chatBloc.close);

    await tester.pumpWidget(buildChatAreaApp(chatBloc: chatBloc));

    final input = tester.widget<TextField>(find.byType(TextField));

    expect(find.text("pending"), findsOneWidget);
    expect(input.enabled, false);
  });

  testWidgets("ChatPage lays out ChatArea and ChatSidebar in a row", (tester) async {
    final repository = ChatRepository();

    await tester.pumpWidget(buildChatPageApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(ChatArea), findsOneWidget);
    expect(find.byType(VerticalDivider), findsWidgets);
    expect(find.byType(ChatSidebar), findsOneWidget);
  });

  testWidgets("ChatPage selects chats and marks the active sidebar tile", (tester) async {
    final repository = ChatRepository();
    await seedChat(repository: repository, id: "chat_1", prompt: "first chat");
    await seedChat(repository: repository, id: "chat_2", prompt: "second chat");

    await tester.pumpWidget(buildChatPageApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, "second chat"));
    await tester.pumpAndSettle();

    expect(find.text("This is a mock response to: second chat"), findsOneWidget);

    final selectedTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, "second chat")
    );
    expect(selectedTile.selected, true);
  });

  testWidgets("ChatPage creates chats and shows the empty conversation state", (tester) async {
    final repository = ChatRepository();

    await tester.pumpWidget(buildChatPageApp(repository: repository));
    await tester.pumpAndSettle();

    await createChat(tester);

    expect(find.text("No messages yet"), findsOneWidget);
    expect(find.widgetWithText(ListTile, "New Chat"), findsOneWidget);
  });

  testWidgets("ChatPage clears the conversation after deleting the active chat", (tester) async {
    final repository = ChatRepository();
    await seedChat(repository: repository, id: "chat_1", prompt: "delete me");

    await tester.pumpWidget(buildChatPageApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, "delete me"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text("Select or create a chat"), findsOneWidget);
    expect(find.text("No chats yet"), findsOneWidget);
  });

  testWidgets("ChatPage reloads chats after a sent message completes", (tester) async {
    final repository = TrackingChatRepository();

    await tester.pumpWidget(buildChatPageApp(repository: repository));
    await tester.pumpAndSettle();

    await createChat(tester);
    final countBeforeSend = repository.loadAllCount;

    await sendMessage(tester, "listener title refresh");

    expect(repository.loadAllCount, countBeforeSend + 1);
    expect(find.widgetWithText(ListTile, "listener title refresh"), findsOneWidget);
  });
}
