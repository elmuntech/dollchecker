import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/development/data/development_repository.dart';
import 'package:dollchecker/features/development/domain/development_summary.dart';
import 'package:dollchecker/features/development/presentation/dashboard_screen.dart';
import 'package:dollchecker/features/development/presentation/skill_radar.dart';

import '../../helpers.dart';

Map<String, dynamic> row(String skill, num avg, int max, int scans) => {
      'skill': skill,
      'avg_score': avg,
      'max_score': max,
      'scan_count': scans,
    };

void main() {
  final children = [
    const ChildProfile(id: 'c1', name: 'Alma'),
  ];

  Future<void> pumpDashboard(
    WidgetTester tester,
    DevelopmentSummary summary, {
    List<ChildProfile>? kids,
  }) {
    return pumpApp(
      tester,
      const DashboardScreen(),
      // The dashboard is a long scroll; a tall surface renders it all at once.
      surfaceSize: const Size(1000, 2400),
      overrides: [
        childrenProvider.overrideWith((ref) async => kids ?? children),
        developmentSummaryProvider.overrideWith((ref) async => summary),
      ],
    );
  }

  testWidgets('empty summary invites the user to scan', (tester) async {
    await pumpDashboard(tester, DevelopmentSummary.empty);
    expect(
      find.textContaining('Scan a few toys'),
      findsOneWidget,
    );
    expect(find.byType(SkillRadar), findsNothing);
  });

  testWidgets('renders the index, radar, strengths and gaps', (tester) async {
    final summary = DevelopmentSummary.fromRows([
      row('fine_motor', 90, 95, 3),
      row('creativity', 70, 80, 3),
      row('logic', 30, 40, 3),
    ]);
    await pumpDashboard(tester, summary);

    // (90 + 70 + 30) / 3 = 63
    expect(find.text('63'), findsOneWidget);
    expect(find.text('Development index'), findsOneWidget);
    expect(find.text('Based on 3 scans'), findsOneWidget);
    expect(find.byType(SkillRadar), findsOneWidget);
    expect(find.text('Strengths'), findsOneWidget);
    expect(find.text('Gaps to fill'), findsOneWidget);
  });

  testWidgets('lists skills no scan has rated yet', (tester) async {
    final summary = DevelopmentSummary.fromRows([row('fine_motor', 90, 95, 1)]);
    await pumpDashboard(tester, summary);
    expect(find.text('Not measured yet'), findsOneWidget);
    // 19 of the 20 canonical skills are unrated here.
    expect(summary.uncoveredSkills, hasLength(19));
  });

  testWidgets('hides the child switcher for a single child', (tester) async {
    final summary = DevelopmentSummary.fromRows([row('fine_motor', 90, 95, 1)]);
    await pumpDashboard(tester, summary);
    expect(find.text('Alma'), findsNothing);
  });

  testWidgets('shows the child switcher once there are two children',
      (tester) async {
    final summary = DevelopmentSummary.fromRows([row('fine_motor', 90, 95, 1)]);
    await pumpDashboard(
      tester,
      summary,
      kids: const [
        ChildProfile(id: 'c1', name: 'Alma'),
        ChildProfile(id: 'c2', name: 'Bek'),
      ],
    );
    expect(find.text('Alma'), findsOneWidget);
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpApp(
      tester,
      const DashboardScreen(),
      locale: const Locale('ru'),
      overrides: [
        childrenProvider.overrideWith((ref) async => children),
        developmentSummaryProvider.overrideWith(
          (ref) async => DevelopmentSummary.fromRows([row('logic', 50, 60, 2)]),
        ),
      ],
    );
    expect(find.text('Развитие'), findsOneWidget);
    expect(find.text('По 2 сканам'), findsOneWidget);
  });
}
