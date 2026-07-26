/// Canonical development-skill keys and their grouping.
///
/// The keys mirror the `skill_key` enum in `supabase/migrations/0001_init.sql`
/// and `SKILL_KEYS` in `supabase/functions/analyze-toy/schema.ts`. All three
/// must stay in sync — a test asserts the Dart side stays complete and unique.
library;

const kSkillKeys = <String>[
  'fine_motor',
  'gross_motor',
  'creativity',
  'problem_solving',
  'language',
  'numeracy',
  'logic',
  'stem',
  'social_emotional',
  'imagination',
  'memory',
  'spatial_reasoning',
  'hand_eye_coordination',
  'focus_attention',
  'reading_readiness',
  'independent_play',
  'collaboration',
  'sensory',
  'confidence',
  'curiosity',
];

/// Twenty skills are too many axes to read on a radar chart, so the dashboard
/// rolls them up into six developmental domains.
enum SkillGroup { motor, cognitive, creative, social, language, exploration }

const _groupMembers = <SkillGroup, List<String>>{
  SkillGroup.motor: [
    'fine_motor',
    'gross_motor',
    'hand_eye_coordination',
  ],
  SkillGroup.cognitive: [
    'problem_solving',
    'logic',
    'memory',
    'focus_attention',
    'numeracy',
  ],
  SkillGroup.creative: [
    'creativity',
    'imagination',
  ],
  SkillGroup.social: [
    'social_emotional',
    'collaboration',
    'confidence',
    'independent_play',
  ],
  SkillGroup.language: [
    'language',
    'reading_readiness',
  ],
  SkillGroup.exploration: [
    'stem',
    'spatial_reasoning',
    'sensory',
    'curiosity',
  ],
};

/// The skills belonging to [group], in display order.
List<String> skillsInGroup(SkillGroup group) => _groupMembers[group]!;

final Map<String, SkillGroup> _groupOfSkill = {
  for (final entry in _groupMembers.entries)
    for (final skill in entry.value) skill: entry.key,
};

/// The group a skill belongs to, or null for an unrecognized key (which can
/// happen if the backend gains a skill the app does not know about yet).
SkillGroup? groupOfSkill(String skill) => _groupOfSkill[skill];
