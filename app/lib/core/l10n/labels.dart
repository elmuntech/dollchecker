import 'package:dollchecker/core/domain/skills.dart';
import 'package:dollchecker/features/auth/domain/auth_failure.dart';
import 'package:dollchecker/features/missions/domain/mission_stats.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// What to tell the user about a failed sign-in, sign-up or reset. Every case
/// is actionable: it says what to do next, not what the server called it.
String authFailureLabel(AppLocalizations l, AuthFailure failure) {
  switch (failure) {
    case AuthFailure.invalidCredentials:
      return l.authInvalidCredentials;
    case AuthFailure.emailNotConfirmed:
      return l.authEmailNotConfirmed;
    case AuthFailure.emailTaken:
      return l.authEmailTaken;
    case AuthFailure.weakPassword:
      return l.authWeakPassword;
    case AuthFailure.invalidEmail:
      return l.authInvalidEmail;
    case AuthFailure.rateLimited:
      return l.authRateLimited;
    case AuthFailure.network:
      return l.authNetwork;
    case AuthFailure.unknown:
      return l.authError;
  }
}

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

/// Localized name of a developmental domain (the radar chart's axes).
String skillGroupLabel(AppLocalizations l, SkillGroup group) {
  switch (group) {
    case SkillGroup.motor:
      return l.group_motor;
    case SkillGroup.cognitive:
      return l.group_cognitive;
    case SkillGroup.creative:
      return l.group_creative;
    case SkillGroup.social:
      return l.group_social;
    case SkillGroup.language:
      return l.group_language;
    case SkillGroup.exploration:
      return l.group_exploration;
  }
}

/// Localized name of a gamification milestone.
String missionBadgeLabel(AppLocalizations l, MissionBadge badge) {
  switch (badge) {
    case MissionBadge.firstMission:
      return l.badge_firstMission;
    case MissionBadge.threeDayStreak:
      return l.badge_threeDayStreak;
    case MissionBadge.weekStreak:
      return l.badge_weekStreak;
    case MissionBadge.monthStreak:
      return l.badge_monthStreak;
    case MissionBadge.tenMissions:
      return l.badge_tenMissions;
    case MissionBadge.fiftyMissions:
      return l.badge_fiftyMissions;
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
