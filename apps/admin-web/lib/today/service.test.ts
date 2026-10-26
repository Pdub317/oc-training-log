import { describe, expect, it } from "vitest";
import {
  getToday,
  TodayDataError,
  TrackAccessDeniedError,
  type AuthorizedTrack,
  type ProgrammingDayRecord,
  type TodayRepository,
} from "./service";

const track: AuthorizedTrack = {
  id: "00000000-0000-0000-0000-000000000202",
  code: "GP",
  name: "General Population",
  memberTimeZone: "America/Los_Angeles",
  gymTimeZone: "America/Los_Angeles",
};

const programmingDay: ProgrammingDayRecord = {
  id: "00000000-0000-0000-0000-000000000804",
  title: "Tuesday GP",
  coachNotes: null,
  blocks: [
    {
      id: "00000000-0000-0000-0000-000000000904",
      type: "strength",
      title: "Strength",
      instructions: null,
      displayOrder: 0,
      movements: [
        {
          id: "00000000-0000-0000-0000-000000001001",
          movementId: "00000000-0000-0000-0000-000000000701",
          name: "Kneeling Landmine Press",
          prescriptionText: "4 x 8 each side",
          coachNotes: null,
          substitutions: [],
          resultSchema: "weighted_fixed_reps",
          displayOrder: 0,
        },
      ],
    },
  ],
};

describe("Today service", () => {
  it.each([false, true])(
    "maps the repository closure flag %s into the public response",
    async (isClosed) => {
      const response = await getToday(
        { userId: "member-1", trackCode: "GP" },
        {
          repository: createRepository(track, { ...programmingDay, isClosed }),
          clock: { now: () => new Date("2026-09-14T18:00:00Z") },
        },
      );
      expect(response.state).toBe(isClosed ? "closed" : "published");
      if (response.state !== "no_programming") {
        expect(response.programmingDay).not.toHaveProperty("isClosed");
        if (!isClosed)
          expect(response.programmingDay).toHaveProperty(
            "blocks",
            programmingDay.blocks,
          );
      }
    },
  );

  it("resolves the workout date in the member's time zone", async () => {
    const repository = createRepository(track, programmingDay);

    const response = await getToday(
      { userId: "member-1", trackCode: "GP" },
      {
        repository,
        clock: { now: () => new Date("2026-08-05T06:30:00.000Z") },
      },
    );

    expect(response).toMatchObject({
      state: "published",
      workoutDate: "2026-08-04",
      timeZone: "America/Los_Angeles",
    });
    expect(repository.requestedDate).toBe("2026-08-04");
  });

  it("uses the gym time zone when a member time zone is unavailable or invalid", async () => {
    const repository = createRepository(
      { ...track, memberTimeZone: "Not/A_Time_Zone" },
      null,
    );

    const response = await getToday(
      { userId: "member-1", trackCode: "GP" },
      {
        repository,
        clock: { now: () => new Date("2026-08-04T23:00:00.000Z") },
      },
    );

    expect(response).toEqual({
      state: "no_programming",
      workoutDate: "2026-08-04",
      timeZone: "America/Los_Angeles",
      track: {
        id: track.id,
        code: "GP",
        name: "General Population",
      },
      isCompleted: false,
      canCreateFreeText: true,
    });
  });

  it("denies a track without an active membership", async () => {
    const repository = createRepository(null, null);

    await expect(
      getToday({ userId: "member-1", trackCode: "SP" }, { repository }),
    ).rejects.toBeInstanceOf(TrackAccessDeniedError);
  });

  it("loads an explicitly requested prior date after authorizing the track", async () => {
    const repository = createRepository(track, programmingDay, true);

    const response = await getToday(
      {
        userId: "member-1",
        trackCode: "GP",
        workoutDate: "2026-07-14",
      },
      {
        repository,
        clock: { now: () => new Date("2026-08-05T06:30:00.000Z") },
      },
    );

    expect(response.workoutDate).toBe("2026-07-14");
    expect(response.isCompleted).toBe(true);
    expect(repository.requestedDate).toBe("2026-07-14");
  });

  it("rejects malformed or unordered database data before returning it", async () => {
    const invalidDay = {
      ...programmingDay,
      blocks: [
        programmingDay.blocks[0]!,
        { ...programmingDay.blocks[0]!, displayOrder: 0 },
      ],
    };
    const repository = createRepository(track, invalidDay);

    await expect(
      getToday({ userId: "member-1", trackCode: "GP" }, { repository }),
    ).rejects.toBeInstanceOf(TodayDataError);
  });
});

function createRepository(
  authorizedTrack: AuthorizedTrack | null,
  day: ProgrammingDayRecord | null,
  completed = false,
): TodayRepository & { requestedDate: string | null } {
  return {
    requestedDate: null,
    async findActiveTrack() {
      return authorizedTrack;
    },
    async findPublishedProgramming(_trackId, workoutDate) {
      this.requestedDate = workoutDate;
      return day;
    },
    async hasCompletedWorkout() {
      return completed;
    },
  };
}
