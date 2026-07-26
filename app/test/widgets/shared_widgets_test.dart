import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/domain/skills.dart';
import 'package:dollchecker/features/development/domain/development_summary.dart';
import 'package:dollchecker/features/development/presentation/skill_radar.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';
import 'package:dollchecker/shared/widgets/score_gauge.dart';
import 'package:dollchecker/shared/widgets/skill_bar.dart';

import '../helpers.dart';

void main() {
  group('SafetyBadge', () {
    testWidgets('shows the localized verdict and score', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: SafetyBadge(level: SafetyLevel.green, score: 91),
        ),
      );
      expect(find.text('Looks safe'), findsOneWidget);
      expect(find.text('91'), findsOneWidget);
    });

    testWidgets('renders a red verdict', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SafetyBadge(level: SafetyLevel.red, score: 12)),
      );
      expect(find.text('Not recommended'), findsOneWidget);
    });

    testWidgets('translates into Russian', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SafetyBadge(level: SafetyLevel.green, score: 91)),
        locale: const Locale('ru'),
      );
      expect(find.text('Выглядит безопасно'), findsOneWidget);
    });
  });

  group('SafetyChip', () {
    testWidgets('renders a compact verdict with a dot', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SafetyChip(level: SafetyLevel.yellow)),
      );
      expect(find.text('Use caution'), findsOneWidget);
      expect(find.byType(SafetyDot), findsOneWidget);
    });

    testWidgets('an unknown level renders a dash, not a crash', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SafetyChip(level: SafetyLevel.unknown)),
      );
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('ScoreGauge', () {
    testWidgets('shows the score and label', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: ScoreGauge(score: 73, label: 'Educational')),
      );
      expect(find.text('73'), findsOneWidget);
      expect(find.text('Educational'), findsOneWidget);
    });

    testWidgets('clamps an out-of-range score into the arc', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: ScoreGauge(score: 140, label: 'X')),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });
  });

  group('SkillBar', () {
    testWidgets('shows the label and score', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(body: SkillBar(label: 'Fine motor', score: 64)),
      );
      expect(find.text('Fine motor'), findsOneWidget);
      expect(find.text('64'), findsOneWidget);
    });
  });

  group('SkillRadar', () {
    testWidgets('draws one axis per developmental domain', (tester) async {
      final summary = DevelopmentSummary.fromRows([
        {'skill': 'fine_motor', 'avg_score': 80, 'max_score': 90, 'scan_count': 2},
        {'skill': 'logic', 'avg_score': 40, 'max_score': 50, 'scan_count': 2},
      ]);
      await pumpApp(
        tester,
        Scaffold(body: SkillRadar(groups: summary.groups)),
      );
      expect(find.byType(SkillRadar), findsOneWidget);
      expect(summary.groups, hasLength(SkillGroup.values.length));
    });
  });
}
