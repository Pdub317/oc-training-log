import type { TrackCode } from "./index";

export const PROGRAMMING_BLOCK_TYPES = [
  "warm_up",
  "jumps",
  "strength",
  "accessory",
  "wod",
  "finisher",
  "recovery",
  "other",
] as const;

export const PROGRAMMING_RESULT_SCHEMAS = [
  "weighted_fixed_reps",
  "weighted_variable_reps",
  "height_or_distance",
  "for_time",
  "max_repetitions",
  "calories_or_distance",
  "rounds_and_reps",
  "notes_only",
] as const;

export type ProgrammingBlockType = (typeof PROGRAMMING_BLOCK_TYPES)[number];
export type ProgrammingResultSchema =
  (typeof PROGRAMMING_RESULT_SCHEMAS)[number];
export type ParseConfidence = "high" | "medium" | "low";

export interface ImportedMovementDraft {
  id: string;
  displayName: string;
  prescriptionText: string;
  coachNotes: string;
  optionGroupKey?: string | null;
  optionGroupLabel?: string | null;
  resultSchema: ProgrammingResultSchema;
  confidence: ParseConfidence;
  requiresReview: boolean;
  warnings: string[];
}

export interface ImportedBlockDraft {
  id: string;
  type: ProgrammingBlockType;
  title: string;
  instructions: string;
  confidence: ParseConfidence;
  warnings: string[];
  movements: ImportedMovementDraft[];
}

export interface ImportedDayDraft {
  id: string;
  workoutDate: string;
  title: string;
  coachNotes: string;
  isClosed?: boolean;
  sourceExcerpt: string;
  confidence: ParseConfidence;
  warnings: string[];
  blocks: ImportedBlockDraft[];
}

export interface ProgrammingImportDraft {
  trackCode: TrackCode;
  sourceText: string;
  days: ImportedDayDraft[];
  warnings: string[];
}

const monthNumbers: Record<string, number> = {
  january: 1,
  jan: 1,
  february: 2,
  feb: 2,
  march: 3,
  mar: 3,
  april: 4,
  apr: 4,
  may: 5,
  june: 6,
  jun: 6,
  july: 7,
  jul: 7,
  august: 8,
  aug: 8,
  september: 9,
  sep: 9,
  sept: 9,
  october: 10,
  oct: 10,
  november: 11,
  nov: 11,
  december: 12,
  dec: 12,
};

const blockAliases: Record<string, ProgrammingBlockType> = {
  warmup: "warm_up",
  "warm up": "warm_up",
  wu: "warm_up",
  j: "jumps",
  jump: "jumps",
  jumps: "jumps",
  speed: "jumps",
  sprint: "jumps",
  sprints: "jumps",
  s: "strength",
  strength: "strength",
  a: "accessory",
  accessory: "accessory",
  accessories: "accessory",
  wod: "wod",
  workout: "wod",
  conditioning: "wod",
  f: "finisher",
  finisher: "finisher",
  recovery: "recovery",
  cooldown: "recovery",
  "cool down": "recovery",
  other: "other",
};

const blockTitles: Record<ProgrammingBlockType, string> = {
  warm_up: "Warm-up",
  jumps: "Jumps",
  strength: "Strength",
  accessory: "Accessory",
  wod: "WOD",
  finisher: "Finisher",
  recovery: "Recovery",
  other: "Other",
};

function draftId(prefix: string, ...parts: number[]) {
  return `${prefix}-${parts.join("-")}`;
}

function isoDate(year: number, month: number, day: number) {
  const candidate = new Date(Date.UTC(year, month - 1, day));
  if (
    candidate.getUTCFullYear() !== year ||
    candidate.getUTCMonth() !== month - 1 ||
    candidate.getUTCDate() !== day
  ) {
    return null;
  }
  return `${year.toString().padStart(4, "0")}-${month
    .toString()
    .padStart(2, "0")}-${day.toString().padStart(2, "0")}`;
}

function parseDateHeading(line: string, defaultYear: number) {
  const cleaned = line
    .trim()
    .replace(
      /^(monday|tuesday|wednesday|thursday|friday|saturday|sunday),?\s+/i,
      "",
    )
    .replace(/[|]+$/, "")
    .trim();

  const named = cleaned.match(
    /^([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?$/i,
  );
  if (named) {
    const month = monthNumbers[named[1]!.toLowerCase()];
    if (month) {
      return isoDate(
        named[3] ? Number(named[3]) : defaultYear,
        month,
        Number(named[2]),
      );
    }
  }

  const numeric = cleaned.match(/^(\d{1,4})[\/-](\d{1,2})[\/-](\d{1,4})$/);
  if (numeric) {
    const first = Number(numeric[1]);
    const second = Number(numeric[2]);
    const third = Number(numeric[3]);
    return first > 31
      ? isoDate(first, second, third)
      : isoDate(third < 100 ? 2000 + third : third, first, second);
  }

  const monthDay = cleaned.match(/^(\d{1,2})[\/-](\d{1,2})$/);
  return monthDay
    ? isoDate(defaultYear, Number(monthDay[1]), Number(monthDay[2]))
    : null;
}

function parseBlockHeading(line: string) {
  const match = line.match(
    /^\s*(warm[ -]?up|wu|jumps?|speed|sprints?|strength|accessor(?:y|ies)|wod|workout|conditioning|finisher|recovery|cool[ -]?down|other|j|s|a|f)\s*(?::|\s+-\s+)?\s*(.*)$/i,
  );
  if (!match) return null;
  const normalized = match[1]!.toLowerCase().replace(/-/g, " ");
  const type = blockAliases[normalized];
  return type ? { type, content: match[2]!.trim() } : null;
}

function displayNameFromPrescription(text: string) {
  const setRepStarts = [...text.matchAll(/\b\d+\s*x\s*\d+\s+/gi)];
  const finalSetRepStart = setRepStarts.at(-1)?.index;
  const titleSource =
    finalSetRepStart && finalSetRepStart > 0
      ? text.slice(finalSetRepStart)
      : text;
  const cleaned = titleSource
    .replace(/^[-*•.)\s]+/, "")
    .replace(/^\d+\s*(?:x|sets?\s+of)\s*\d+(?:-\d+)?\s*/i, "")
    .replace(/^\d+(?:-\d+)?\s*(?:reps?\s+(?:of\s+)?)?/i, "")
    .trim();
  const candidate = cleaned
    .split(/(?:;|\s+at\s+\d|\s+with\s+\d|,)/i)[0]!
    .trim();
  return (candidate || text.trim()).slice(0, 200);
}

function splitMovementCandidates(
  text: string,
  blockType: ProgrammingBlockType,
) {
  if (blockType !== "strength") return [text];

  const candidates: string[] = [];
  for (const clause of text.split(
    /\s+[—–-]\s+(?=(?:between\s+each\s+set\b|\d+\s*x\s*(?:\d+|max)\b))/i,
  )) {
    const cleaned = clause.trim();
    if (cleaned) candidates.push(cleaned);
  }
  return candidates.length > 1 ? candidates : [text];
}

function inferResultSchema(
  text: string,
  blockType: ProgrammingBlockType,
): Pick<
  ImportedMovementDraft,
  "resultSchema" | "confidence" | "requiresReview" | "warnings"
> {
  if (blockType === "warm_up" || blockType === "recovery") {
    return {
      resultSchema: "notes_only",
      confidence: "high",
      requiresReview: false,
      warnings: [],
    };
  }

  const requestsTime = /\bfor\s+time\b|\btime\s+trial\b/i.test(text);
  const requestsMaxCalories =
    /\bmax(?:imum)?\s+(?:effort\s+)?(?:calories|cals?)\b/i.test(text);

  if (requestsTime && requestsMaxCalories) {
    return {
      resultSchema: "notes_only",
      confidence: "low",
      requiresReview: true,
      warnings: [
        "Split the workout alternatives so each option uses the result requested by its prompt.",
      ],
    };
  }
  if (requestsTime) {
    return {
      resultSchema: "for_time",
      confidence: "high",
      requiresReview: false,
      warnings: [],
    };
  }
  if (/\bamrap\b|\brounds?\s*(?:and|\+)\s*reps?\b/i.test(text)) {
    return {
      resultSchema: "rounds_and_reps",
      confidence: "medium",
      requiresReview: true,
      warnings: [
        "Confirm that members should enter completed rounds and reps.",
      ],
    };
  }
  if (
    /\bmax(?:imum)?\s+(?:unbroken\s+|effort\s+)?(?:reps?|pull-ups?|push-ups?|calories|cals?)\b/i.test(
      text,
    )
  ) {
    const isCalories = /\b(?:calories|cals?)\b/i.test(text);
    return {
      resultSchema: isCalories ? "calories_or_distance" : "max_repetitions",
      confidence: "medium",
      requiresReview: true,
      warnings: [
        isCalories
          ? "Confirm whether members enter calories or distance."
          : "Confirm that members should enter repetitions.",
      ],
    };
  }
  if (/\b(?:1|2|3|4|5|6|8|10|12)\s*(?:rep|max|rm)\b/i.test(text)) {
    return {
      resultSchema: "weighted_fixed_reps",
      confidence: "high",
      requiresReview: false,
      warnings: [],
    };
  }
  if (/\b\d+\s*[-–]\s*\d+\s*(?:rep|max|rm)\b/i.test(text)) {
    return {
      resultSchema: "weighted_variable_reps",
      confidence: "medium",
      requiresReview: true,
      warnings: ["Confirm that both weight and completed reps are required."],
    };
  }
  if (
    blockType === "strength" &&
    (/\b\d+\s*x\s*\d+\b/i.test(text) || /\b\d+\s+sets?\b/i.test(text))
  ) {
    return {
      resultSchema: "weighted_fixed_reps",
      confidence: "medium",
      requiresReview: true,
      warnings: ["Confirm that members should enter the weight used."],
    };
  }
  if (
    /(?:\b(?:max|height|distance)\b.*\b(?:vertical|broad|box)\s+jump\b|\b(?:vertical|broad|box)\s+jump\b.*\b(?:max|height|distance)\b)/i.test(
      text,
    )
  ) {
    return {
      resultSchema: "height_or_distance",
      confidence: "medium",
      requiresReview: true,
      warnings: ["Confirm the height or distance measurement."],
    };
  }

  return {
    resultSchema: "notes_only",
    confidence: "low",
    requiresReview: true,
    warnings: [
      "Choose how members record this item, or confirm that it remains unscored.",
    ],
  };
}

function parseDay(
  lines: string[],
  workoutDate: string,
  sourceExcerpt: string,
  dayIndex: number,
  trackCode: TrackCode,
): ImportedDayDraft {
  const meaningfulLines = lines.map((line) => line.trim()).filter(Boolean);
  if (meaningfulLines.length === 1 && /^closed$/i.test(meaningfulLines[0]!)) {
    return {
      id: draftId("day", dayIndex),
      workoutDate,
      title: "Gym Closed",
      coachNotes: "",
      isClosed: true,
      sourceExcerpt,
      confidence: "high",
      warnings: [],
      blocks: [],
    };
  }
  const blocks: ImportedBlockDraft[] = [];
  let current: { type: ProgrammingBlockType; content: string[] } | null = null;
  const finishCurrentBlock = () => {
    if (!current) return;
    const isExplicitlyNotApplicable =
      current.content.length > 0 &&
      current.content.every((line) => /^n\/?a$/i.test(line.trim()));
    const retainNotApplicable =
      (current.type === "strength" || current.type === "accessory") &&
      (isExplicitlyNotApplicable || current.content.length === 0);
    if (
      retainNotApplicable ||
      (!isExplicitlyNotApplicable && current.content.length > 0)
    ) {
      blocks.push(buildBlock(current, dayIndex, blocks.length));
    }
  };

  for (const line of lines) {
    const heading = parseBlockHeading(line);
    if (heading) {
      finishCurrentBlock();
      current = {
        type: heading.type,
        content: heading.content ? [heading.content] : [],
      };
      continue;
    }
    if (line.trim()) {
      current ??= { type: "other", content: [] };
      current.content.push(line.trim());
    }
  }
  finishCurrentBlock();

  const warnings: string[] = [];
  if (blocks.length === 0)
    warnings.push("No programming blocks were found for this date.");
  if (blocks.some((block) => block.type === "other")) {
    warnings.push("Some content did not have a recognized block heading.");
  }
  const titleBlocks = [
    ...blocks.filter((block) => block.type === "strength"),
    ...blocks.filter(
      (block) =>
        block.type !== "strength" &&
        block.type !== "warm_up" &&
        block.type !== "recovery",
    ),
    ...blocks.filter(
      (block) => block.type === "warm_up" || block.type === "recovery",
    ),
  ];
  const firstNamedMovement = titleBlocks
    .flatMap((block) => block.movements)
    .find((movement) => movement.displayName.length > 0);

  return {
    id: draftId("day", dayIndex),
    workoutDate,
    title: firstNamedMovement?.displayName
      ? `${trackCode} · ${firstNamedMovement.displayName}`
      : `${trackCode} Training`,
    coachNotes: "",
    isClosed: false,
    sourceExcerpt,
    confidence: warnings.length === 0 ? "high" : "medium",
    warnings,
    blocks,
  };
}

function buildBlock(
  source: { type: ProgrammingBlockType; content: string[] },
  dayIndex: number,
  blockIndex: number,
): ImportedBlockDraft {
  const meaningful = source.content.filter(
    (line) => line.trim() && !/^n\/?a$/i.test(line.trim()),
  );
  const movements = meaningful
    .flatMap((line) => splitMovementCandidates(line, source.type))
    .map((line, movementIndex) => ({
      id: draftId("movement", dayIndex, blockIndex, movementIndex),
      displayName: displayNameFromPrescription(line),
      prescriptionText: line.trim().slice(0, 2000),
      coachNotes: "",
      optionGroupKey: null,
      optionGroupLabel: null,
      ...inferResultSchema(line, source.type),
    }));
  if (
    movements.length === 0 &&
    (source.type === "strength" || source.type === "accessory")
  ) {
    movements.push({
      id: draftId("movement", dayIndex, blockIndex, 0),
      displayName: "N/A",
      prescriptionText: "N/A",
      coachNotes: "",
      optionGroupKey: null,
      optionGroupLabel: null,
      resultSchema: "notes_only",
      confidence: "high",
      requiresReview: false,
      warnings: [],
    });
  }
  const warnings =
    source.type === "other"
      ? ["Choose the correct block label before publishing."]
      : [];
  return {
    id: draftId("block", dayIndex, blockIndex),
    type: source.type,
    title: blockTitles[source.type],
    instructions: "",
    confidence: source.type === "other" ? "low" : "high",
    warnings,
    movements,
  };
}

export function parseProgrammingSource(input: {
  sourceText: string;
  trackCode: TrackCode;
  defaultYear: number;
}): ProgrammingImportDraft {
  const sourceText = input.sourceText.replace(/\r\n?/g, "\n").trim();
  const lines = sourceText.split("\n");
  const headings = lines.flatMap((line, index) => {
    const workoutDate = parseDateHeading(line, input.defaultYear);
    return workoutDate ? [{ index, workoutDate }] : [];
  });
  const warnings: string[] = [];

  if (headings.length === 0) {
    return {
      trackCode: input.trackCode,
      sourceText,
      days: [],
      warnings: [
        "No date headings were found. Add dates such as “Tuesday, September 8, 2026” and parse again.",
      ],
    };
  }
  if (
    headings[0]!.index > 0 &&
    lines.slice(0, headings[0]!.index).some((line) => line.trim())
  ) {
    warnings.push(
      "Text before the first date was preserved in the source but not assigned to a workout.",
    );
  }

  const days = headings.map((heading, index) => {
    const end = headings[index + 1]?.index ?? lines.length;
    const section = lines.slice(heading.index + 1, end);
    return parseDay(
      section,
      heading.workoutDate,
      lines.slice(heading.index, end).join("\n").trim(),
      index,
      input.trackCode,
    );
  });
  const duplicateDates = days
    .map((day) => day.workoutDate)
    .filter((date, index, all) => all.indexOf(date) !== index);
  if (duplicateDates.length) {
    warnings.push(
      `Duplicate dates found: ${[...new Set(duplicateDates)].join(", ")}.`,
    );
  }

  return { trackCode: input.trackCode, sourceText, days, warnings };
}

export function programmingDraftBlockingIssues(draft: ProgrammingImportDraft) {
  const issues = [...draft.warnings];
  if (draft.days.length === 0)
    issues.push("At least one dated workout is required.");
  for (const day of draft.days) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day.workoutDate)) {
      issues.push(`${day.title || "Workout"} needs a valid date.`);
    }
    if (!day.title.trim()) issues.push(`${day.workoutDate} needs a title.`);
    if (day.isClosed) {
      if (day.blocks.length > 0)
        issues.push(
          `${day.workoutDate}: Gym Closed cannot contain workout blocks.`,
        );
      continue;
    }
    if (day.blocks.length === 0)
      issues.push(`${day.workoutDate} needs at least one block.`);
    for (const block of day.blocks) {
      if (block.type === "other")
        issues.push(
          `${day.workoutDate}: choose a block label for “${block.title}”.`,
        );
      if (block.movements.length === 0)
        issues.push(`${day.workoutDate}: ${block.title} has no content.`);
      for (const movement of block.movements) {
        if (!movement.displayName.trim() || !movement.prescriptionText.trim()) {
          issues.push(
            `${day.workoutDate}: every item needs a name and prescription.`,
          );
        }
        if (movement.requiresReview) {
          issues.push(`${day.workoutDate}: confirm “${movement.displayName}”.`);
        }
        if (
          (block.type === "warm_up" || block.type === "recovery") &&
          movement.resultSchema !== "notes_only"
        ) {
          issues.push(
            `${day.workoutDate}: ${block.title} items must remain unscored.`,
          );
        }
      }
    }
  }
  return [...new Set(issues)];
}
