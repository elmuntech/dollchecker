// Pure helpers for the chat-toy function.
//
// Kept free of Deno/Supabase imports so they can be unit-tested with
// `deno test` without any network or environment setup.

/** Longest question we accept. Roughly a screen of text. */
export const MAX_QUESTION_CHARS = 2000;

/** How many stored messages travel back as context. */
export const HISTORY_LIMIT = 20;

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

/** Rejects an empty or oversized question before it costs a model call. */
export function normalizeQuestion(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const trimmed = v.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_QUESTION_CHARS) return null;
  return trimmed;
}

/**
 * The last [limit] messages, oldest first, as the API wants them.
 *
 * Rows arrive newest-first (that is the cheap query), and anything with an
 * unexpected role is dropped rather than passed through — the conversation is
 * replayed to the model, so a malformed row is a way to put words in its mouth.
 */
export function toHistory(
  rows: readonly Record<string, unknown>[],
  limit: number = HISTORY_LIMIT,
): ChatMessage[] {
  const clean: ChatMessage[] = [];
  for (const row of rows) {
    const role = row.role;
    const content = row.content;
    if (role !== "user" && role !== "assistant") continue;
    if (typeof content !== "string" || content.trim() === "") continue;
    clean.push({ role, content });
  }
  return clean.slice(0, limit).reverse();
}

/**
 * The toy the conversation is about, as plain text for the model.
 *
 * Only the parts a parent would ask about are included: the whole stored
 * analysis is far larger than the conversation needs, and paying to re-read it
 * on every turn is waste, not context.
 */
export function toyContext(analysis: unknown): string {
  const root = typeof analysis === "object" && analysis !== null
    ? analysis as Record<string, unknown>
    : {};

  const pick = (path: string[]): unknown => {
    let node: unknown = root;
    for (const key of path) {
      if (typeof node !== "object" || node === null) return undefined;
      node = (node as Record<string, unknown>)[key];
    }
    return node;
  };

  const str = (v: unknown): string | null =>
    typeof v === "string" && v.trim() !== "" ? v.trim() : null;

  const lines: string[] = [];
  const name = str(pick(["identification", "name"]));
  const brand = str(pick(["identification", "brand"]));
  lines.push(`Toy: ${name ?? "unidentified"}${brand ? ` (${brand})` : ""}`);

  const ageLabel = str(pick(["age_recommendation", "label"]));
  if (ageLabel) lines.push(`Recommended age: ${ageLabel}`);

  const safety = str(pick(["safety", "overall"])) ??
    str(pick(["safety_overall"]));
  const safetySummary = str(pick(["safety", "summary"]));
  if (safety) lines.push(`Safety verdict: ${safety}`);
  if (safetySummary) lines.push(`Safety notes: ${safetySummary}`);

  const hazards = pick(["safety", "hazards"]);
  if (Array.isArray(hazards) && hazards.length > 0) {
    const names = hazards
      .map((h) =>
        typeof h === "object" && h !== null
          ? str((h as Record<string, unknown>).type)
          : null
      )
      .filter((h): h is string => h !== null);
    if (names.length > 0) lines.push(`Flagged hazards: ${names.join(", ")}`);
  }

  const eduSummary = str(pick(["development", "educational_summary"]));
  if (eduSummary) lines.push(`Development: ${eduSummary}`);

  return lines.join("\n");
}

/** The child the questions are about, when one is known. */
export function childContext(ageMonths: number | null): string {
  return ageMonths === null
    ? "The child's age is unknown."
    : `The child is about ${ageMonths} months old.`;
}

export function buildUserText(opts: {
  question: string;
  toy: string;
  child: string;
  locale: string;
}): string {
  const lang = opts.locale === "ru" ? "Russian (ru)" : "English (en)";
  return `The parent is asking about this toy:
${opts.toy}

${opts.child}

Question: ${opts.question}

Answer in ${lang}.`;
}
