import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/chat/data/chat_repository.dart';
import 'package:dollchecker/features/chat/domain/chat_message.dart';
import 'package:dollchecker/features/chat/presentation/chat_screen.dart';

import '../../helpers.dart';

ChatMessage message(String id, {required bool mine, required String text}) =>
    ChatMessage.fromRow({
      'id': id,
      'role': mine ? 'user' : 'assistant',
      'content': text,
      'created_at': '2026-08-01T10:00:00Z',
    });

/// Answers without a server.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    this.reply = 'Try stacking them by colour.',
    this.premiumRequired = false,
    this.rateLimited = false,
    this.fails = false,
    this.stored = const [],
  });

  final String reply;
  final bool premiumRequired;
  final bool rateLimited;
  final bool fails;
  final List<ChatMessage> stored;

  final List<String> asked = [];

  @override
  Future<List<ChatMessage>> history(String scanId) async => stored;

  @override
  Future<String> ask({
    required String scanId,
    required String question,
  }) async {
    asked.add(question);
    if (premiumRequired) throw ChatPremiumRequiredException();
    if (rateLimited) throw ChatRateLimitedException();
    if (fails) throw ChatFailedException();
    return reply;
  }
}

void main() {
  Future<void> pumpChat(
    WidgetTester tester,
    FakeChatRepository repo, {
    Locale locale = const Locale('en'),
  }) {
    return pumpApp(
      tester,
      const ChatScreen(scanId: 'scan-1'),
      locale: locale,
      surfaceSize: const Size(600, 1200),
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
  }

  testWidgets('an empty thread suggests what to ask', (tester) async {
    // A blank chat box is a hard place to start.
    await pumpChat(tester, FakeChatRepository());
    expect(find.text("Is this still right for my child's age?"), findsOneWidget);
    expect(find.text('What should I watch out for?'), findsOneWidget);
  });

  testWidgets('shows the stored conversation', (tester) async {
    await pumpChat(
      tester,
      FakeChatRepository(stored: [
        message('1', mine: true, text: 'Is it loud?'),
        message('2', mine: false, text: 'Moderately.'),
      ]),
    );
    expect(find.text('Is it loud?'), findsOneWidget);
    expect(find.text('Moderately.'), findsOneWidget);
  });

  testWidgets('tapping a starter asks it', (tester) async {
    final repo = FakeChatRepository();
    await pumpChat(tester, repo);
    await tester.tap(find.text('What should I watch out for?'));
    await tester.pumpAndSettle();

    expect(repo.asked.single, 'What should I watch out for?');
    expect(find.text('Try stacking them by colour.'), findsOneWidget);
  });

  testWidgets('a typed question appears immediately, with its answer',
      (tester) async {
    final repo = FakeChatRepository(reply: 'Rotate it out for a week.');
    await pumpChat(tester, repo);
    await tester.enterText(find.byType(TextField), 'She ignores it');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repo.asked.single, 'She ignores it');
    expect(find.text('She ignores it'), findsOneWidget);
    expect(find.text('Rotate it out for a week.'), findsOneWidget);
  });

  testWidgets('an empty question is not sent', (tester) async {
    final repo = FakeChatRepository();
    await pumpChat(tester, repo);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repo.asked, isEmpty);
  });

  testWidgets('a free account is offered the upgrade, not an error',
      (tester) async {
    await pumpChat(tester, FakeChatRepository(premiumRequired: true));
    await tester.enterText(find.byType(TextField), 'Is it loud?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Chat is part of Premium'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });

  testWidgets('a failure says so and keeps the question on screen',
      (tester) async {
    await pumpChat(tester, FakeChatRepository(fails: true));
    await tester.enterText(find.byType(TextField), 'Is it loud?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Could not get an answer. Please try again.'),
        findsOneWidget);
    expect(find.text('Is it loud?'), findsOneWidget);
  });

  testWidgets('asking too fast says to wait, not that it broke',
      (tester) async {
    await pumpChat(tester, FakeChatRepository(rateLimited: true));
    await tester.enterText(find.byType(TextField), 'Is it loud?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wait a moment'), findsOneWidget);
    expect(find.textContaining('Could not get an answer'), findsNothing);
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpChat(tester, FakeChatRepository(), locale: const Locale('ru'));
    expect(find.text('Спросить об игрушке'), findsOneWidget);
  });
}
