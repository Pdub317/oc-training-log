import {
  todayResponseSchema,
  type ResultSchemaType,
  type TodayResponse,
  type TrackCode,
  type WorkoutBlockType,
} from "@oc-training-log/contracts";

export type AuthorizedTrack = {
  id: string;
  code: TrackCode;
  name: string;
  memberTimeZone: string | null;
  gymTimeZone: string;
};

export type PrescribedMovementRecord = {
  id: string;
  movementId: string | null;
  name: string;
  prescriptionText: string;
  coachNotes: string | null;
  substitutions: string[];
  optionGroupKey?: string | null;
  optionGroupLabel?: string | null;
  resultSchema: ResultSchemaType;
  displayOrder: number;
};

export type WorkoutBlockRecord = {
  id: string;
  type: WorkoutBlockType;
  title: string;
  instructions: string | null;
  displayOrder: number;
  movements: PrescribedMovementRecord[];
};

export type ProgrammingDayRecord = {
  id: string;
  title: string;
  coachNotes: string | null;
  isClosed?: boolean;
  blocks: WorkoutBlockRecord[];
};

export interface TodayRepository {
  findActiveTrack(
    userId: string,
    trackCode: TrackCode,
  ): Promise<AuthorizedTrack | null>;
  findPublishedProgramming(
    trackId: string,
    workoutDate: string,
  ): Promise<ProgrammingDayRecord | null>;
  hasCompletedWorkout(
    userId: string,
    trackId: string,
    workoutDate: string,
  ): Promise<boolean>;
}

export interface Clock {
  now(): Date;
}

export class TrackAccessDeniedError extends Error {
  constructor() {
    super("The member does not have access to the requested track.");
    this.name = "TrackAccessDeniedError";
  }
}

export class TodayDataError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = "TodayDataError";
  }
}

const systemClock: Clock = {
  now: () => new Date(),
};

export async function getToday(
  input: { userId: string; trackCode: TrackCode; workoutDate?: string },
  dependencies: { repository: TodayRepository; clock?: Clock },
): Promise<TodayResponse> {
  const track = await dependencies.repository.findActiveTrack(
    input.userId,
    input.trackCode,
  );

  if (!track) {
    throw new TrackAccessDeniedError();
  }

  const timeZone = resolveTimeZone(track.memberTimeZone, track.gymTimeZone);
  const workoutDate =
    input.workoutDate ??
    formatLocalDate((dependencies.clock ?? systemClock).now(), timeZone);
  const [programmingDay, isCompleted] = await Promise.all([
    dependencies.repository.findPublishedProgramming(track.id, workoutDate),
    dependencies.repository.hasCompletedWorkout(
      input.userId,
      track.id,
      workoutDate,
    ),
  ]);

  const response = programmingDay?.isClosed
    ? {
        state: "closed" as const,
        workoutDate,
        timeZone,
        track: { id: track.id, code: track.code, name: track.name },
        isCompleted: false as const,
        programmingDay: {
          id: programmingDay.id,
          title: programmingDay.title,
          coachNotes: programmingDay.coachNotes,
        },
      }
    : programmingDay
      ? {
          state: "published" as const,
          workoutDate,
          timeZone,
          track: { id: track.id, code: track.code, name: track.name },
          isCompleted,
          programmingDay: {
            id: programmingDay.id,
            title: programmingDay.title,
            coachNotes: programmingDay.coachNotes,
            blocks: programmingDay.blocks,
          },
        }
      : {
          state: "no_programming" as const,
          workoutDate,
          timeZone,
          track: { id: track.id, code: track.code, name: track.name },
          isCompleted,
          canCreateFreeText: true as const,
        };

  const parsed = todayResponseSchema.safeParse(response);
  if (!parsed.success) {
    throw new TodayDataError("Today data did not match the public contract.", {
      cause: parsed.error,
    });
  }

  return parsed.data;
}

export function formatLocalDate(now: Date, timeZone: string): string {
  if (Number.isNaN(now.getTime())) {
    throw new TodayDataError("The clock returned an invalid date.");
  }

  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(now);
  } catch (error) {
    throw new TodayDataError("The resolved time zone is invalid.", {
      cause: error,
    });
  }

  const values = Object.fromEntries(
    parts
      .filter(
        ({ type }) => type === "year" || type === "month" || type === "day",
      )
      .map(({ type, value }) => [type, value]),
  );

  if (!values.year || !values.month || !values.day) {
    throw new TodayDataError("The local workout date could not be resolved.");
  }

  return `${values.year}-${values.month}-${values.day}`;
}

function resolveTimeZone(
  memberTimeZone: string | null,
  gymTimeZone: string,
): string {
  if (memberTimeZone && isValidTimeZone(memberTimeZone)) {
    return memberTimeZone;
  }

  if (isValidTimeZone(gymTimeZone)) {
    return gymTimeZone;
  }

  throw new TodayDataError("No valid time zone is available for this member.");
}

function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone }).format();
    return true;
  } catch {
    return false;
  }
}
