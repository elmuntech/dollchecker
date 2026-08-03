import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/paging/paged_list.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/play/data/play_repository.dart';
import 'package:dollchecker/features/play/domain/play_idea_entry.dart';
import 'package:dollchecker/features/play/presentation/play_screen.dart';

import '../../helpers.dart';

PlayIdeaEntry idea(
  String title, {
  bool favorited = false,
  List<String> skills = const ['fine_motor'],
}) =>
    PlayIdeaEntry(
      id: 'idea-$title',
      scanId: 'scan-1',
      toyName: 'Stacking Rings',
      title: title,
      description: 'Do the thing.',
      skillsTargeted: skills,
      minAgeMonths: 12,
      durationMinutes: 10,
      difficulty: 'easy',
      isFavorited: favorited,
    );

void main() {
  Future<void> pumpPlay(
    WidgetTester tester,
    List<PlayIdeaEntry> ideas, {
    Locale locale = const Locale('en'),
    bool hasMore = false,
    _StubPlay? stub,
  }) {
    return pumpApp(
      tester,
      const PlayScreen(),
      locale: locale,
      overrides: [
        childrenProvider
            .overrideWith((ref) async => [const ChildProfile(id: 'c1', name: 'Alma')]),
        playIdeasProvider.overrideWith(
          () => stub ?? _StubPlay(PagedList(items: ideas, hasMore: hasMore)),
        ),
      ],
    );
  }

  testWidgets('empty state points at the first scan', (tester) async {
    await pumpPlay(tester, const []);
    expect(find.textContaining('after your first scan'), findsOneWidget);
  });

  testWidgets('features an idea of the day above the list', (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    expect(find.text('Idea of the day'), findsOneWidget);
    // Once as the featured card, once in the full list.
    expect(find.text('Rainbow tower'), findsNWidgets(2));
  });

  testWidgets('shows duration, difficulty and targeted skills',
      (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    expect(find.text('10 min'), findsNWidgets(2));
    expect(find.text('Easy'), findsNWidgets(2));
    expect(find.text('Fine motor'), findsNWidgets(2));
  });

  testWidgets('links back to the toy the idea came from', (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    expect(find.text('From Stacking Rings'), findsNWidgets(2));
  });

  testWidgets('favorited ideas show a filled star', (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower', favorited: true)]);
    expect(find.byIcon(Icons.star), findsWidgets);
  });

  testWidgets('toggling the favorites chip updates the provider',
      (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    expect(container.read(playFavoritesOnlyProvider), isTrue);
  });

  testWidgets('the skill filter starts at "Any skill"', (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    expect(find.widgetWithText(ActionChip, 'Any skill'), findsOneWidget);
  });

  testWidgets('picking a skill sets the filter', (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    await tester.tap(find.widgetWithText(ActionChip, 'Any skill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Creativity').last);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    expect(container.read(playSkillFilterProvider), 'creativity');
  });

  testWidgets('offers the next page instead of stopping at a hidden cap',
      (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')], hasMore: true);
    expect(find.text('Load more'), findsOneWidget);
    // Idle, not loading — the footer must not claim the app is busy.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no footer once the feed has ended', (tester) async {
    await pumpPlay(tester, [idea('Rainbow tower')]);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('tapping the footer asks for the next page', (tester) async {
    final stub = _StubPlay(
      PagedList(items: [idea('Rainbow tower')], hasMore: true),
    );
    await pumpPlay(tester, const [], stub: stub);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(stub.loadMoreCalls, 1);
  });

  testWidgets('the star toggles in place rather than reloading the feed',
      (tester) async {
    final stub = _StubPlay(
      PagedList(items: [idea('Rainbow tower')], hasMore: false),
    );
    await pumpPlay(tester, const [], stub: stub);
    // The featured card and the list row both show the same idea; either
    // star is the one under test.
    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();
    expect(stub.favorited, ['idea-Rainbow tower']);
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpPlay(tester, [idea('Башня')], locale: const Locale('ru'));
    expect(find.text('Игровой коуч'), findsOneWidget);
    expect(find.text('Идея дня'), findsOneWidget);
  });
}

class _StubPlay extends PlayPageController {
  _StubPlay(this._page);
  final PagedList<PlayIdeaEntry> _page;

  int loadMoreCalls = 0;
  final List<String> favorited = [];

  @override
  Future<PagedList<PlayIdeaEntry>> build() async => _page;

  @override
  Future<void> loadMore() async => loadMoreCalls++;

  @override
  Future<void> toggleFavorite(PlayIdeaEntry idea) async {
    favorited.add(idea.id);
  }
}
