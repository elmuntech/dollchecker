// The JSON Schema Claude is forced to conform to via `output_config.format`.
//
// Structured-output constraints we respect here:
//   * every object sets `additionalProperties: false` and lists every key in `required`
//   * no numeric (`minimum`/`maximum`) or array-length (`minItems`) constraints — those
//     are not supported; ranges are described in prose instead.
//   * enums keep stable English machine values so scores aggregate cleanly across scans.

// Canonical development-skill keys — MUST match the `skill_key` enum in the DB
// migration and the SkillKey enum in the Flutter app.
export const SKILL_KEYS = [
  "fine_motor",
  "gross_motor",
  "creativity",
  "problem_solving",
  "language",
  "numeracy",
  "logic",
  "stem",
  "social_emotional",
  "imagination",
  "memory",
  "spatial_reasoning",
  "hand_eye_coordination",
  "focus_attention",
  "reading_readiness",
  "independent_play",
  "collaboration",
  "sensory",
  "confidence",
  "curiosity",
] as const;

export const HAZARD_TYPES = [
  "choking",
  "small_parts",
  "magnets",
  "batteries",
  "sharp_edges",
  "toxic",
  "cord_strangulation",
  "loud_sound",
  "other",
] as const;

const strObj = (
  props: Record<string, unknown>,
  required: string[],
) => ({
  type: "object",
  additionalProperties: false,
  properties: props,
  required,
});

export const ANALYSIS_SCHEMA = strObj(
  {
    identification: strObj(
      {
        name: { type: "string", description: "Best guess of the toy's name." },
        brand: {
          type: "string",
          description: "Brand if visible, otherwise 'unknown'.",
        },
        category: {
          type: "string",
          description: "e.g. 'building blocks', 'plush', 'ride-on'.",
        },
        confidence: {
          type: "number",
          description: "0.0–1.0 confidence in the identification.",
        },
        detected_language: { type: "string", enum: ["en", "ru"] },
      },
      ["name", "brand", "category", "confidence", "detected_language"],
    ),
    age_recommendation: strObj(
      {
        min_months: {
          type: "integer",
          description: "Minimum recommended age in months.",
        },
        max_months: {
          type: "integer",
          description:
            "Maximum recommended age in months, or 216 (18y) if open-ended.",
        },
        label: {
          type: "string",
          description: "Localized human label, e.g. '3+ years'.",
        },
      },
      ["min_months", "max_months", "label"],
    ),
    materials: {
      type: "array",
      items: { type: "string" },
      description:
        "Materials, e.g. ['plastic','wood']. English machine values.",
    },
    safety: strObj(
      {
        overall: { type: "string", enum: ["green", "yellow", "red"] },
        score: {
          type: "integer",
          description: "0–100 overall safety score (higher = safer).",
        },
        hazards: {
          type: "array",
          items: strObj(
            {
              type: {
                type: "string",
                enum: HAZARD_TYPES as unknown as string[],
              },
              severity: { type: "string", enum: ["low", "medium", "high"] },
              description: {
                type: "string",
                description: "Localized explanation of the hazard.",
              },
              recommendation: {
                type: "string",
                description: "Localized parent recommendation.",
              },
            },
            ["type", "severity", "description", "recommendation"],
          ),
        },
        summary: { type: "string", description: "Localized safety summary." },
        supervision_level: {
          type: "string",
          enum: ["none", "occasional", "constant"],
        },
        cleaning: { type: "string", description: "Localized cleaning tip." },
        storage: { type: "string", description: "Localized storage tip." },
        disclaimer: {
          type: "string",
          description:
            "Localized disclaimer: AI guidance only, not a substitute for official certifications/recalls; always supervise.",
        },
      },
      [
        "overall",
        "score",
        "hazards",
        "summary",
        "supervision_level",
        "cleaning",
        "storage",
        "disclaimer",
      ],
    ),
    development: strObj(
      {
        educational_score: {
          type: "integer",
          description: "0–100 overall educational value.",
        },
        educational_summary: {
          type: "string",
          description:
            "Localized: why the score, what it lacks, how to improve.",
        },
        skills: {
          type: "array",
          description:
            "One entry per relevant skill. Prefer covering all canonical skills.",
          items: strObj(
            {
              skill: {
                type: "string",
                enum: SKILL_KEYS as unknown as string[],
              },
              score: {
                type: "integer",
                description: "0–100 how much this toy develops the skill.",
              },
              reason: { type: "string", description: "Localized rationale." },
              how_to_maximize: {
                type: "string",
                description: "Localized: how a parent maximizes this benefit.",
              },
            },
            ["skill", "score", "reason", "how_to_maximize"],
          ),
        },
      },
      ["educational_score", "educational_summary", "skills"],
    ),
    play_coach: strObj(
      {
        ideas: {
          type: "array",
          description: "10–20 creative, age-appropriate play ideas.",
          items: strObj(
            {
              title: { type: "string" },
              description: { type: "string" },
              skills_targeted: {
                type: "array",
                items: {
                  type: "string",
                  enum: SKILL_KEYS as unknown as string[],
                },
              },
              min_age_months: { type: "integer" },
              duration_minutes: { type: "integer" },
              difficulty: { type: "string", enum: ["easy", "medium", "hard"] },
            },
            [
              "title",
              "description",
              "skills_targeted",
              "min_age_months",
              "duration_minutes",
              "difficulty",
            ],
          ),
        },
      },
      ["ideas"],
    ),
  },
  [
    "identification",
    "age_recommendation",
    "materials",
    "safety",
    "development",
    "play_coach",
  ],
);
