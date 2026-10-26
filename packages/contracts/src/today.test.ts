import { describe, expect, it } from "vitest";
import { todayResponseSchema } from "./today";

const track = {
  id: "10000000-0000-4000-8000-000000000001",
  code: "SP",
  name: "Sports Performance",
} as const;

const publishedToday = {
  state: "published",
  workoutDate: "2026-09-01",
  timeZone: "America/Los_Angeles",
  track,
  isCompleted: false,
  programmingDay: {
    id: "20000000-0000-4000-8000-000000000001",
    title: "Lower Body Strength",
    coachNotes: "Move with intent and leave one good rep in reserve.",
    blocks: [
      {
        id: "30000000-0000-4000-8000-000000000001",
        type: "warm_up",
        title: "Warm-up",
        instructions: null,
        displayOrder: 0,
        movements: [
          {
            id: "40000000-0000-4000-8000-000000000001",
            movementId: null,
            name: "Movement preparation",
            prescriptionText: "2 rounds at a conversational pace",
            coachNotes: null,
            substitutions: [],
            resultSchema: "notes_only",
            displayOrder: 0,
          },
        ],
      },
      {
        id: "30000000-0000-4000-8000-000000000002",
        type: "strength",
        title: "Strength",
        instructions: "Rest two minutes between working sets.",
        displayOrder: 1,
        movements: [
          {
            id: "40000000-0000-4000-8000-000000000002",
            movementId: "50000000-0000-4000-8000-000000000001",
            name: "Back Squat",
            prescriptionText: "4 x 5 @ 75%, 2:00 rest",
            coachNotes: "Use a controlled descent.",
            substitutions: ["Goblet squat"],
            resultSchema: "weighted_fixed_reps",
            displayOrder: 0,
          },
        ],
      },
    ],
  },
} as const;

describe("Today response contract", () => {
  it("accepts a published workout while preserving coach-authored text", () => {
    const result = todayResponseSchema.parse(publishedToday);

    expect(result.state).toBe("published");
    if (result.state === "published") {
      expect(
        result.programmingDay.blocks[1]?.movements[0]?.prescriptionText,
      ).toBe("4 x 5 @ 75%, 2:00 rest");
    }
  });

  it("accepts an explicit no-programming response with free-text logging", () => {
    expect(
      todayResponseSchema.parse({
        state: "no_programming",
        workoutDate: "2026-09-01",
        timeZone: "America/Los_Angeles",
        track: { ...track, code: "GP", name: "General Population" },
        isCompleted: true,
        canCreateFreeText: true,
      }),
    ).toMatchObject({ state: "no_programming", canCreateFreeText: true });
  });

  it("accepts a visible closed day without workout blocks", () => {
    expect(
      todayResponseSchema.parse({
        state: "closed",
        workoutDate: "2026-09-06",
        timeZone: "America/Los_Angeles",
        track: { ...track, code: "GP", name: "General Population" },
        isCompleted: false,
        programmingDay: {
          id: "20000000-0000-4000-8000-000000000006",
          title: "Gym Closed",
          coachNotes: null,
        },
      }),
    ).toMatchObject({ state: "closed", isCompleted: false });
  });

  it("accepts prompt-driven result formats within one option group", () => {
    const strength = publishedToday.programmingDay.blocks[1]!;
    const result = todayResponseSchema.parse({
      ...publishedToday,
      programmingDay: {
        ...publishedToday.programmingDay,
        blocks: [
          {
            ...strength,
            type: "wod",
            movements: [
              {
                ...strength.movements[0]!,
                name: "1k Row",
                resultSchema: "for_time",
                optionGroupKey: "monostructural-test",
                optionGroupLabel: "Select each option completed",
              },
              {
                ...strength.movements[0]!,
                id: "40000000-0000-4000-8000-000000000003",
                name: "4-minute Assault Bike",
                resultSchema: "calories_or_distance",
                optionGroupKey: "monostructural-test",
                optionGroupLabel: "Select each option completed",
                displayOrder: 1,
              },
            ],
          },
        ],
      },
    });

    expect(result.state).toBe("published");
  });

  it("rejects unordered blocks and scoreable warm-up movements", () => {
    const warmUp = publishedToday.programmingDay.blocks[0]!;
    const strength = publishedToday.programmingDay.blocks[1]!;
    const invalid = {
      ...publishedToday,
      programmingDay: {
        ...publishedToday.programmingDay,
        blocks: [
          {
            ...warmUp,
            movements: [
              {
                ...warmUp.movements[0]!,
                resultSchema: "weighted_fixed_reps",
              },
            ],
          },
          { ...strength, displayOrder: 0 },
        ],
      },
    };

    const result = todayResponseSchema.safeParse(invalid);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues.map((issue) => issue.message)).toEqual(
        expect.arrayContaining([
          "warm_up movements must be read-only",
          "displayOrder values must be strictly increasing",
        ]),
      );
    }
  });

  it("rejects unsupported tracks, unpublished states, and private fields", () => {
    expect(() =>
      todayResponseSchema.parse({
        ...publishedToday,
        track: { ...track, code: "UNASSIGNED" },
      }),
    ).toThrow();
    expect(() =>
      todayResponseSchema.parse({ ...publishedToday, state: "draft" }),
    ).toThrow();
    expect(() =>
      todayResponseSchema.parse({
        ...publishedToday,
        serviceRoleKey: "must-not-cross-the-client-boundary",
      }),
    ).toThrow();
  });
});
