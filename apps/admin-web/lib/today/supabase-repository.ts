import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AuthorizedTrack,
  ProgrammingDayRecord,
  TodayRepository,
  WorkoutBlockRecord,
} from "./service";
import { TodayDataError } from "./service";

type TrackRow = {
  id: string;
  code: AuthorizedTrack["code"];
  name: string;
  gym_id: string;
};

type DayRow = {
  id: string;
  title: string;
  coach_notes: string | null;
  is_closed: boolean;
};

type BlockRow = {
  id: string;
  type: WorkoutBlockRecord["type"];
  title: string;
  instructions: string | null;
  display_order: number;
};

type MovementRow = {
  id: string;
  block_id: string;
  movement_id: string | null;
  display_name: string;
  prescription_text: string;
  coach_notes: string | null;
  substitutions: string[];
  option_group_key: string | null;
  option_group_label: string | null;
  result_schema: WorkoutBlockRecord["movements"][number]["resultSchema"];
  display_order: number;
};

export class SupabaseTodayRepository implements TodayRepository {
  constructor(private readonly client: SupabaseClient) {}

  async findActiveTrack(
    userId: string,
    trackCode: AuthorizedTrack["code"],
  ): Promise<AuthorizedTrack | null> {
    const memberships = await this.client
      .from("track_memberships")
      .select("track_id")
      .eq("user_id", userId)
      .eq("status", "active");

    assertQuerySucceeded(memberships.error, "active track memberships");
    const trackIds = (memberships.data ?? []).map((row) => row.track_id);
    if (trackIds.length === 0) {
      return null;
    }

    const trackResult = await this.client
      .from("training_tracks")
      .select("id, code, name, gym_id")
      .eq("code", trackCode)
      .eq("status", "active")
      .in("id", trackIds)
      .maybeSingle();

    assertQuerySucceeded(trackResult.error, "authorized track");
    if (!trackResult.data) {
      return null;
    }

    const track = trackResult.data as TrackRow;
    const [userResult, gymResult] = await Promise.all([
      this.client.from("users").select("time_zone").eq("id", userId).single(),
      this.client
        .from("gyms")
        .select("timezone")
        .eq("id", track.gym_id)
        .single(),
    ]);

    assertQuerySucceeded(userResult.error, "member time zone");
    assertQuerySucceeded(gymResult.error, "gym time zone");

    return {
      id: track.id,
      code: track.code,
      name: track.name,
      memberTimeZone: userResult.data.time_zone,
      gymTimeZone: gymResult.data.timezone,
    };
  }

  async findPublishedProgramming(
    trackId: string,
    workoutDate: string,
  ): Promise<ProgrammingDayRecord | null> {
    const dayResult = await this.client
      .from("programming_days")
      .select("id, title, coach_notes, is_closed")
      .eq("track_id", trackId)
      .eq("workout_date", workoutDate)
      .eq("status", "published")
      .maybeSingle();

    assertQuerySucceeded(dayResult.error, "published programming day");
    if (!dayResult.data) {
      return null;
    }

    const day = dayResult.data as DayRow;
    const blockResult = await this.client
      .from("workout_blocks")
      .select("id, type, title, instructions, display_order")
      .eq("programming_day_id", day.id)
      .order("display_order", { ascending: true });

    assertQuerySucceeded(blockResult.error, "workout blocks");
    const blockRows = (blockResult.data ?? []) as BlockRow[];
    const blockIds = blockRows.map(({ id }) => id);
    let movementRows: MovementRow[] = [];

    if (blockIds.length > 0) {
      const movementResult = await this.client
        .from("prescribed_movements")
        .select(
          "id, block_id, movement_id, display_name, prescription_text, coach_notes, substitutions, option_group_key, option_group_label, result_schema, display_order",
        )
        .in("block_id", blockIds)
        .order("display_order", { ascending: true });

      assertQuerySucceeded(movementResult.error, "prescribed movements");
      movementRows = (movementResult.data ?? []) as MovementRow[];
    }

    return {
      id: day.id,
      title: day.title,
      coachNotes: day.coach_notes,
      isClosed: day.is_closed,
      blocks: blockRows.map((block) => ({
        id: block.id,
        type: block.type,
        title: block.title,
        instructions: block.instructions,
        displayOrder: block.display_order,
        movements: movementRows
          .filter((movement) => movement.block_id === block.id)
          .map((movement) => ({
            id: movement.id,
            movementId: movement.movement_id,
            name: movement.display_name,
            prescriptionText: movement.prescription_text,
            coachNotes: movement.coach_notes,
            substitutions: movement.substitutions,
            optionGroupKey: movement.option_group_key,
            optionGroupLabel: movement.option_group_label,
            resultSchema: movement.result_schema,
            displayOrder: movement.display_order,
          })),
      })),
    };
  }

  async hasCompletedWorkout(
    userId: string,
    trackId: string,
    workoutDate: string,
  ): Promise<boolean> {
    const result = await this.client
      .from("workout_logs")
      .select("id")
      .eq("user_id", userId)
      .eq("track_id", trackId)
      .eq("workout_date", workoutDate)
      .limit(1)
      .maybeSingle();

    assertQuerySucceeded(result.error, "completed workout");
    return result.data !== null;
  }
}

function assertQuerySucceeded(
  error: { message: string } | null,
  resource: string,
): asserts error is null {
  if (error) {
    throw new TodayDataError(`Unable to load ${resource}.`, { cause: error });
  }
}
