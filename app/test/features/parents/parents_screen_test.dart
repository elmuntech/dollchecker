import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/config/legal_links.dart';
import 'package:dollchecker/core/config/store_billing.dart';
import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/features/auth/data/auth_repository.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/missions/domain/day.dart';
import 'package:dollchecker/features/parents/data/parents_repository.dart';
import 'package:dollchecker/features/parents/domain/household_report.dart';
import 'package:dollchecker/features/parents/domain/safety_watch.dart';
import 'package:dollchecker/features/parents/presentation/parents_screen.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';

import '../../helpers.dart';

final _today = DateTime(2026, 7, 26);

const _alma = ChildProfile(id: 'c1', name: 'Alma');
const _bek = ChildProfile(id: 'c2', name: 'Bek');

ChildWeek week(
  ChildProfile child, {
  int scans = 0,
  int planned = 0,
  int completed = 0,
  Set<int> activeDays = const <int>{},
  int developmentIndex = 0,
}) =>
    ChildWeek(
      child: child,
      scans: scans,
      missionsPlanned: planned,
      missionsCompleted: completed,
      activeDays: activeDays,
      developmentIndex: developmentIndex,
    );

Toy toy(String name, {String safety = 'red'}) => Toy.fromRow({
      'id': 'toy-$name',
      'name': name,
      'owned': true,
      'scan_count': 1,
      'latest_safety': safety,
      'last_scanned_at': '2026-07-25T09:00:00Z',
    });

/// Stands in for the real repository so "delete account" can be exercised
/// without a server.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.rateLimited = false});

  final bool rateLimited;
  bool deleted = false;

  @override
  Future<void> deleteAccount() async {
    if (rateLimited) throw const RateLimitedException(60);
    deleted = true;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async =>
      SignUpOutcome.signedIn;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    HouseholdReport? report,
    SafetyWatch? watch,
    QuotaStatus quota = const QuotaStatus(tier: 'free', used: 3, resetAt: null),
    List<ChildProfile> children = const [_alma],
    LegalLinks links = LegalLinks.none,
    AuthRepository? auth,
    bool canBuy = true,
    Locale locale = const Locale('en'),
  }) {
    return pumpApp(
      tester,
      const ParentsScreen(),
      locale: locale,
      surfaceSize: const Size(1000, 2400),
      overrides: [
        todayProvider.overrideWithValue(_today),
        childrenProvider.overrideWith((ref) async => children),
        householdReportProvider.overrideWith(
          (ref) async => report ?? HouseholdReport.empty,
        ),
        safetyWatchProvider.overrideWith((ref) async => watch ?? SafetyWatch.empty),
        quotaProvider.overrideWith((ref) async => quota),
        legalLinksProvider.overrideWithValue(links),
        billingAllowedProvider.overrideWithValue(canBuy),
        authRepositoryProvider
            .overrideWithValue(auth ?? FakeAuthRepository()),
        signedImageProvider.overrideWith((ref, arg) async => null),
      ],
    );
  }

  testWidgets('leads with the household week', (tester) async {
    await pumpPanel(
      tester,
      report: HouseholdReport(
        totalScans: 4,
        children: [
          week(
            _alma,
            scans: 4,
            planned: 6,
            completed: 5,
            activeDays: {epochDay(_today)},
          ),
        ],
      ),
    );

    expect(find.text('Parents panel'), findsOneWidget);
    expect(find.text('This week at home'), findsOneWidget);
    expect(find.text('Scans'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Active days'), findsOneWidget);
  });

  testWidgets('says so when nothing happened all week', (tester) async {
    await pumpPanel(tester, report: HouseholdReport(children: [week(_alma)], totalScans: 0));
    expect(find.textContaining('No scans and no missions'), findsOneWidget);
  });

  testWidgets('a busy week is not called quiet', (tester) async {
    await pumpPanel(
      tester,
      report: HouseholdReport(totalScans: 1, children: [week(_alma, scans: 1)]),
    );
    expect(find.textContaining('No scans and no missions'), findsNothing);
  });

  group('child cards', () {
    testWidgets('render one per child with their week', (tester) async {
      await pumpPanel(
        tester,
        children: const [_alma, _bek],
        report: HouseholdReport(
          totalScans: 3,
          children: [
            week(_alma, scans: 2, planned: 3, completed: 2, developmentIndex: 71),
            week(_bek, scans: 1),
          ],
        ),
      );

      expect(find.text('Alma'), findsOneWidget);
      expect(find.text('Bek'), findsOneWidget);
      expect(find.text('Scans: 2'), findsOneWidget);
      expect(find.text('2 of 3 done'), findsOneWidget);
      expect(find.textContaining('71'), findsOneWidget);
    });

    testWidgets('a child with no missions this week reads plainly',
        (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.text('No missions this week'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('an unscored child hides the development index', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Development index'), findsNothing);
    });
  });

  group('safety review', () {
    testWidgets('lists the toys that need another look', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
        watch: SafetyWatch.from(
            [toy('Magnet set'), toy('Rattle', safety: 'yellow')]),
      );

      expect(find.text('Safety review'), findsOneWidget);
      expect(find.text('2 toys need attention'), findsOneWidget);
      expect(find.text('Magnet set'), findsOneWidget);
      expect(find.text('Rattle'), findsOneWidget);
    });

    testWidgets('an all-green collection says there is nothing to review',
        (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Nothing to review'), findsOneWidget);
      expect(find.textContaining('need attention'), findsNothing);
    });
  });

  group('account', () {
    testWidgets('shows the plan, the quota and the children', (tester) async {
      await pumpPanel(
        tester,
        children: const [_alma, _bek],
        report: HouseholdReport(
          totalScans: 0,
          children: [week(_alma), week(_bek)],
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.textContaining('Free'), findsOneWidget);
      expect(find.textContaining('7 free scans left'), findsOneWidget);
      expect(find.text('Alma, Bek'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Upgrade'), findsOneWidget);
      expect(find.text('Manage subscription'), findsNothing);
    });

    testWidgets('a premium plan reads as unlimited', (tester) async {
      await pumpPanel(
        tester,
        quota: const QuotaStatus(tier: 'premium', used: 40, resetAt: null),
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Unlimited scans'), findsOneWidget);
      // Cancelling has to be reachable from inside the app.
      expect(find.text('Manage subscription'), findsOneWidget);
      expect(find.text('Upgrade'), findsNothing);
    });

    testWidgets('a build with no purchase path still states the tier',
        (tester) async {
      // The account is premium and must read as premium wherever it was
      // bought. Only the two links that leave for the provider are gone.
      await pumpPanel(
        tester,
        canBuy: false,
        quota: const QuotaStatus(tier: 'premium', used: 40, resetAt: null),
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Unlimited scans'), findsOneWidget);
      expect(find.text('Manage subscription'), findsNothing);
      expect(find.text('Upgrade'), findsNothing);
    });

    testWidgets('a free plan offers no upgrade where none is possible',
        (tester) async {
      await pumpPanel(
        tester,
        canBuy: false,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('7 free scans left'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Upgrade'), findsNothing);
    });
  });

  group('legal links', () {
    testWidgets('are hidden until the pages are published', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.text('Legal'), findsNothing);
      expect(find.text('Privacy policy'), findsNothing);
    });

    testWidgets('show only what is configured', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
        links: const LegalLinks(privacyUrl: 'https://example.com/privacy'),
      );
      expect(find.text('Legal'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of service'), findsNothing);
      expect(find.text('Contact support'), findsNothing);
    });

    testWidgets('show all three when all are configured', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
        links: const LegalLinks(
          privacyUrl: 'https://example.com/privacy',
          termsUrl: 'https://example.com/terms',
          supportEmail: 'help@example.com',
        ),
      );
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
    });
  });

  group('delete account', () {
    testWidgets('is offered, as the stores require', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('states what disappears before doing anything', (tester) async {
      final auth = FakeAuthRepository();
      await pumpPanel(
        tester,
        auth: auth,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('permanently deletes'), findsOneWidget);
      expect(auth.deleted, isFalse);
    });

    testWidgets('cancelling leaves the account alone', (tester) async {
      final auth = FakeAuthRepository();
      await pumpPanel(
        tester,
        auth: auth,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(auth.deleted, isFalse);
    });

    testWidgets('confirming deletes and says so', (tester) async {
      final auth = FakeAuthRepository();
      await pumpPanel(
        tester,
        auth: auth,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete everything'));
      await tester.pumpAndSettle();

      expect(auth.deleted, isTrue);
      expect(find.text('Your account has been deleted.'), findsOneWidget);
    });

    testWidgets('a rate limit does not claim the deletion failed',
        (tester) async {
      // "Could not delete your account" is a frightening thing to say when
      // the account is untouched and the user simply asked twice.
      final auth = FakeAuthRepository(rateLimited: true);
      await pumpPanel(
        tester,
        auth: auth,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete everything'));
      await tester.pumpAndSettle();

      expect(auth.deleted, isFalse);
      expect(find.textContaining('Wait a moment'), findsOneWidget);
      expect(find.textContaining('Could not delete'), findsNothing);
    });
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpPanel(
      tester,
      locale: const Locale('ru'),
      report: HouseholdReport(totalScans: 2, children: [week(_alma, scans: 2)]),
      watch: SafetyWatch.from([toy('Magnet set')]),
    );

    expect(find.text('Родительская панель'), findsOneWidget);
    expect(find.text('Эта неделя дома'), findsOneWidget);
    expect(find.text('Проверка безопасности'), findsOneWidget);
    expect(find.text('1 игрушка требует внимания'), findsOneWidget);
  });
}
