import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/domain/skills.dart';
import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

const _hazardKeys = [
  'choking',
  'small_parts',
  'magnets',
  'batteries',
  'sharp_edges',
  'toxic',
  'cord_strangulation',
  'loud_sound',
  'other',
];

void main() {
  late AppLocalizations en;
  late AppLocalizations ru;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  test('both shipped locales are supported', () {
    expect(supportedLocales.map((l) => l.languageCode),
        containsAll(['en', 'ru']));
  });

  group('skillLabel', () {
    test('translates every canonical skill in English', () {
      for (final key in kSkillKeys) {
        final label = skillLabel(en, key);
        expect(label, isNotEmpty, reason: key);
        expect(label, isNot(key), reason: 'missing English label for $key');
      }
    });

    test('translates every canonical skill in Russian', () {
      for (final key in kSkillKeys) {
        final label = skillLabel(ru, key);
        expect(label, isNotEmpty, reason: key);
        expect(label, isNot(key), reason: 'missing Russian label for $key');
      }
    });

    test('falls back to the raw key for an unknown skill', () {
      expect(skillLabel(en, 'telekinesis'), 'telekinesis');
    });
  });

  group('skillGroupLabel', () {
    test('translates every group in both locales', () {
      for (final group in SkillGroup.values) {
        expect(skillGroupLabel(en, group), isNotEmpty, reason: '$group');
        expect(skillGroupLabel(ru, group), isNotEmpty, reason: '$group');
      }
    });

    test('group labels are distinct within a locale', () {
      final labels =
          SkillGroup.values.map((g) => skillGroupLabel(en, g)).toSet();
      expect(labels, hasLength(SkillGroup.values.length));
    });
  });

  group('hazardLabel', () {
    test('translates every hazard type in both locales', () {
      for (final key in _hazardKeys) {
        expect(hazardLabel(en, key), isNotEmpty, reason: key);
        expect(hazardLabel(ru, key), isNotEmpty, reason: key);
      }
    });

    test('an unknown hazard falls back to "other"', () {
      expect(hazardLabel(en, 'gravitational'), en.hazard_other);
    });
  });

  group('difficultyLabel', () {
    test('maps the three levels', () {
      expect(difficultyLabel(en, 'easy'), en.difficulty_easy);
      expect(difficultyLabel(en, 'medium'), en.difficulty_medium);
      expect(difficultyLabel(en, 'hard'), en.difficulty_hard);
    });

    test('an unknown difficulty reads as medium', () {
      expect(difficultyLabel(en, 'impossible'), en.difficulty_medium);
    });
  });

  group('plurals', () {
    test('English scansLeft distinguishes zero, one and many', () {
      final forms = [en.scansLeft(0), en.scansLeft(1), en.scansLeft(5)];
      expect(forms.every((f) => f.isNotEmpty), isTrue);
      expect(forms.toSet(), hasLength(3));
      expect(en.scansLeft(5), contains('5'));
    });

    test('Russian scansLeft renders its plural forms', () {
      // Russian needs one/few/many; a broken ARB usually collapses them.
      final forms = [ru.scansLeft(0), ru.scansLeft(1), ru.scansLeft(3), ru.scansLeft(11)];
      expect(forms.every((f) => f.isNotEmpty), isTrue);
      expect(forms.toSet().length, greaterThan(2));
    });

    test('scannedTimes and basedOnScans render in both locales', () {
      for (final l in [en, ru]) {
        expect(l.scannedTimes(1), isNotEmpty);
        expect(l.scannedTimes(4), contains('4'));
        expect(l.basedOnScans(1), isNotEmpty);
        expect(l.basedOnScans(9), contains('9'));
        expect(l.ageInMonths(18), contains('18'));
      }
    });
  });

  group('placeholders', () {
    test('interpolate their argument', () {
      expect(en.homeGreeting('Alma'), contains('Alma'));
      expect(en.fromToy('Blocks'), contains('Blocks'));
      expect(ru.fromToy('Кубики'), contains('Кубики'));
      expect(en.removeToyConfirm('Blocks'), contains('Blocks'));
      expect(en.deleteChildConfirm('Alma'), contains('Alma'));
      expect(en.duration(15), contains('15'));
    });
  });
}
