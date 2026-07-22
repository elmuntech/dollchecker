import 'package:dollchecker/l10n/app_localizations.dart';

/// Maps stable English machine keys (from the AI / DB) to localized display
/// labels. The AI returns machine keys; the UI shows translated text.
String skillLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'fine_motor':
      return l.skill_fine_motor;
    case 'gross_motor':
      return l.skill_gross_motor;
    case 'creativity':
      return l.skill_creativity;
    case 'problem_solving':
      return l.skill_problem_solving;
    case 'language':
      return l.skill_language;
    case 'numeracy':
      return l.skill_numeracy;
    case 'logic':
      return l.skill_logic;
    case 'stem':
      return l.skill_stem;
    case 'social_emotional':
      return l.skill_social_emotional;
    case 'imagination':
      return l.skill_imagination;
    case 'memory':
      return l.skill_memory;
    case 'spatial_reasoning':
      return l.skill_spatial_reasoning;
    case 'hand_eye_coordination':
      return l.skill_hand_eye_coordination;
    case 'focus_attention':
      return l.skill_focus_attention;
    case 'reading_readiness':
      return l.skill_reading_readiness;
    case 'independent_play':
      return l.skill_independent_play;
    case 'collaboration':
      return l.skill_collaboration;
    case 'sensory':
      return l.skill_sensory;
    case 'confidence':
      return l.skill_confidence;
    case 'curiosity':
      return l.skill_curiosity;
    default:
      return key;
  }
}

String hazardLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'choking':
      return l.hazard_choking;
    case 'small_parts':
      return l.hazard_small_parts;
    case 'magnets':
      return l.hazard_magnets;
    case 'batteries':
      return l.hazard_batteries;
    case 'sharp_edges':
      return l.hazard_sharp_edges;
    case 'toxic':
      return l.hazard_toxic;
    case 'cord_strangulation':
      return l.hazard_cord_strangulation;
    case 'loud_sound':
      return l.hazard_loud_sound;
    default:
      return l.hazard_other;
  }
}

String difficultyLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'easy':
      return l.difficulty_easy;
    case 'hard':
      return l.difficulty_hard;
    default:
      return l.difficulty_medium;
  }
}
