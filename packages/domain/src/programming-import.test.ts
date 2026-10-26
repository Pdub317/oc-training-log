import { describe, expect, it } from "vitest";
import {
  parseProgrammingSource,
  programmingDraftBlockingIssues,
} from "./programming-import";
import {
  gpSeptemberProgrammingFixture,
  spExampleProgrammingFixture,
} from "./programming-import.test-fixtures";

describe("programming import parser", () => {
  it("parses multiple dated days and case-insensitive blocks without crossing tracks", () => {
    const parsed = parseProgrammingSource({
      trackCode: "GP",
      defaultYear: 2026,
      sourceText: `Tuesday, September 8
Strength: 5x5 Back Squat at 70%
Wod: 4 rounds for time

09/09/2026
WARM-UP: 2 rounds band pull-aparts
Recovery: n/a`,
    });

    expect(parsed.trackCode).toBe("GP");
    expect(parsed.days.map((day) => day.workoutDate)).toEqual([
      "2026-09-08",
      "2026-09-09",
    ]);
    expect(parsed.days[0]?.blocks.map((block) => block.type)).toEqual([
      "strength",
      "wod",
    ]);
    expect(parsed.days[0]?.blocks[0]?.movements[0]?.resultSchema).toBe(
      "weighted_fixed_reps",
    );
    expect(parsed.days[0]?.blocks[1]?.movements[0]?.resultSchema).toBe(
      "for_time",
    );
  });

  it("keeps unknown content reviewable and blocks publication until confirmed", () => {
    const parsed = parseProgrammingSource({
      trackCode: "SP",
      defaultYear: 2026,
      sourceText: `July 23
Accessory: Partner neck and trunk circuit`,
    });
    const movement = parsed.days[0]?.blocks[0]?.movements[0];

    expect(movement?.prescriptionText).toBe("Partner neck and trunk circuit");
    expect(movement?.resultSchema).toBe("notes_only");
    expect(movement?.requiresReview).toBe(true);
    expect(programmingDraftBlockingIssues(parsed)).toContain(
      "2026-07-23: confirm “Partner neck and trunk circuit”.",
    );
  });

  it("does not invent a date when a source has no date heading", () => {
    const parsed = parseProgrammingSource({
      trackCode: "SP",
      defaultYear: 2026,
      sourceText: "Strength: 5x5 back squat",
    });

    expect(parsed.days).toEqual([]);
    expect(programmingDraftBlockingIssues(parsed)).toContain(
      "At least one dated workout is required.",
    );
  });

  it("preserves the complete representative GP September source by date", () => {
    const parsed = parseProgrammingSource({
      trackCode: "GP",
      defaultYear: 2026,
      sourceText: gpSeptemberProgrammingFixture,
    });

    expect(parsed.days).toHaveLength(15);
    expect(parsed.days[0]?.workoutDate).toBe("2026-09-01");
    expect(parsed.days.at(-1)?.workoutDate).toBe("2026-09-15");
    expect(parsed.days[0]?.blocks.map((block) => block.type)).toEqual([
      "warm_up",
      "strength",
      "accessory",
      "wod",
      "recovery",
    ]);
    expect(
      parsed.days[0]?.blocks.some(
        (block) => block.type === "accessory" && block.movements.length === 0,
      ),
    ).toBe(false);
    const jumpTest = parsed.days
      .find((day) => day.workoutDate === "2026-09-14")
      ?.blocks.find((block) => block.type === "strength")?.movements[0];
    expect(jumpTest?.resultSchema).toBe("height_or_distance");
    expect(jumpTest?.requiresReview).toBe(true);

    const combinedStrength = parsed.days
      .find((day) => day.workoutDate === "2026-09-03")
      ?.blocks.find((block) => block.type === "strength");
    expect(combinedStrength?.movements).toHaveLength(2);
    expect(combinedStrength?.movements[0]?.prescriptionText).toContain(
      "back squat",
    );
    expect(combinedStrength?.movements[1]?.prescriptionText).toContain(
      "Russian swings",
    );
    expect(combinedStrength?.movements[1]?.displayName).toContain(
      "Russian swings",
    );
  });

  it("recognizes the abbreviated SP block convention from the representative source", () => {
    const parsed = parseProgrammingSource({
      trackCode: "SP",
      defaultYear: 2026,
      sourceText: spExampleProgrammingFixture,
    });

    expect(parsed.days).toHaveLength(3);
    expect(parsed.days[0]?.blocks.map((block) => block.type)).toEqual([
      "warm_up",
      "jumps",
      "strength",
      "accessory",
      "finisher",
    ]);
    expect(parsed.days[2]?.blocks.map((block) => block.type)).toEqual([
      "warm_up",
      "jumps",
      "jumps",
      "accessory",
      "finisher",
    ]);
    expect(
      parsed.days[0]?.blocks.find((block) => block.type === "strength")
        ?.movements,
    ).toHaveLength(2);
  });

  it("derives scoring from the requested outcome rather than the equipment", () => {
    const parsed = parseProgrammingSource({
      trackCode: "GP",
      defaultYear: 2026,
      sourceText: `September 16
WOD: 500m row for time
September 17
WOD: 50 cal bike for time
September 18
WOD: 4-minute bike for max cals`,
    });

    expect(
      parsed.days.map((day) => day.blocks[0]?.movements[0]?.resultSchema),
    ).toEqual(["for_time", "for_time", "calories_or_distance"]);
  });

  it("requires mixed-outcome alternatives to be split during review", () => {
    const parsed = parseProgrammingSource({
      trackCode: "GP",
      defaultYear: 2026,
      sourceText: `September 14
WOD: 1k row for time, or 4-minute assault bike for max calories`,
    });
    const movement = parsed.days[0]?.blocks[0]?.movements[0];

    expect(movement?.resultSchema).toBe("notes_only");
    expect(movement?.requiresReview).toBe(true);
    expect(movement?.warnings).toContain(
      "Split the workout alternatives so each option uses the result requested by its prompt.",
    );
  });

  it("imports Closed as a visible non-loggable day", () => {
    const parsed = parseProgrammingSource({
      trackCode: "GP",
      defaultYear: 2026,
      sourceText: "Sunday, September 6 2026\nClosed",
    });

    expect(parsed.days[0]).toMatchObject({
      workoutDate: "2026-09-06",
      title: "Gym Closed",
      isClosed: true,
      blocks: [],
    });
    expect(programmingDraftBlockingIssues(parsed)).toEqual([]);
  });
});
