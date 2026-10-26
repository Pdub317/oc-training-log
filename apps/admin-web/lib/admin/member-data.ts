import type { SupabaseClient } from "@supabase/supabase-js";

export type AdminMemberSummary = {
  memberId: string;
  firstName: string;
  lastName: string;
  email: string;
  trackId: string;
  trackCode: string;
  trackName: string;
  joinedAt: string;
};

export type AdminWorkoutSummary = {
  id: string;
  date: string;
  title: string;
  notes: string | null;
  completedAt: string;
  results: {
    id: string;
    name: string;
    prescription: string;
    value: string;
    isPR: boolean;
  }[];
};

export type AdminPersonalRecord = {
  id: string;
  benchmarkId: string;
  benchmarkLabel: string;
  achievedAt: string;
  value: string;
};

export type AdminMemberDetail = {
  member: { id: string; firstName: string; lastName: string; email: string };
  tracks: { id: string; code: string; name: string }[];
  selectedTrack: { id: string; code: string; name: string };
  workouts: AdminWorkoutSummary[];
  personalRecords: AdminPersonalRecord[];
};

type QueryError = { message: string } | null;

export async function loadAdminMemberDirectory(
  client: SupabaseClient,
  gymId: string,
): Promise<AdminMemberSummary[]> {
  const tracksResult = await client
    .from("training_tracks")
    .select("id, code, name")
    .eq("gym_id", gymId)
    .eq("status", "active")
    .order("name");
  assertSucceeded(tracksResult.error);
  const tracks = (tracksResult.data ?? []) as {
    id: string;
    code: string;
    name: string;
  }[];
  if (!tracks.length) return [];

  const membershipsResult = await client
    .from("track_memberships")
    .select("user_id, track_id, joined_at")
    .eq("status", "active")
    .in(
      "track_id",
      tracks.map((track) => track.id),
    );
  assertSucceeded(membershipsResult.error);
  const memberships = (membershipsResult.data ?? []) as {
    user_id: string;
    track_id: string;
    joined_at: string;
  }[];
  if (!memberships.length) return [];

  const memberIds = [
    ...new Set(memberships.map((membership) => membership.user_id)),
  ];
  const [usersResult, gymMembershipsResult] = await Promise.all([
    client
      .from("users")
      .select("id, first_name, last_name, email")
      .in("id", memberIds),
    client
      .from("gym_memberships")
      .select("user_id")
      .eq("gym_id", gymId)
      .eq("role", "member")
      .eq("status", "active")
      .in("user_id", memberIds),
  ]);
  assertSucceeded(usersResult.error);
  assertSucceeded(gymMembershipsResult.error);

  const users = new Map(
    (
      (usersResult.data ?? []) as {
        id: string;
        first_name: string;
        last_name: string;
        email: string;
      }[]
    ).map((user) => [user.id, user]),
  );
  const activeMemberIds = new Set(
    (gymMembershipsResult.data ?? []).map(
      (membership) => membership.user_id as string,
    ),
  );
  const trackMap = new Map(tracks.map((track) => [track.id, track]));

  return memberships
    .flatMap<AdminMemberSummary>((membership) => {
      const user = users.get(membership.user_id);
      const track = trackMap.get(membership.track_id);
      if (!user || !track || !activeMemberIds.has(user.id)) return [];
      return [
        {
          memberId: user.id,
          firstName: user.first_name,
          lastName: user.last_name,
          email: user.email,
          trackId: track.id,
          trackCode: track.code,
          trackName: track.name,
          joinedAt: membership.joined_at,
        },
      ];
    })
    .sort((left, right) =>
      `${left.lastName}\u0000${left.firstName}\u0000${left.trackCode}`.localeCompare(
        `${right.lastName}\u0000${right.firstName}\u0000${right.trackCode}`,
      ),
    );
}

export async function loadAdminMemberDetail(
  client: SupabaseClient,
  gymId: string,
  memberId: string,
  requestedTrackCode?: string,
): Promise<AdminMemberDetail | null> {
  const directory = await loadAdminMemberDirectory(client, gymId);
  const memberships = directory.filter((entry) => entry.memberId === memberId);
  if (!memberships.length) return null;
  const selectedMembership = requestedTrackCode
    ? memberships.find((entry) => entry.trackCode === requestedTrackCode)
    : memberships[0];
  if (!selectedMembership) return null;

  const selectedTrack = {
    id: selectedMembership.trackId,
    code: selectedMembership.trackCode,
    name: selectedMembership.trackName,
  };
  const logsResult = await client
    .from("workout_logs")
    .select(
      "id, programming_day_id, free_text_title, workout_date, notes, completed_at",
    )
    .eq("user_id", memberId)
    .eq("track_id", selectedTrack.id)
    .order("workout_date", { ascending: false })
    .order("completed_at", { ascending: false })
    .limit(50);
  assertSucceeded(logsResult.error);
  const logs = (logsResult.data ?? []) as {
    id: string;
    programming_day_id: string | null;
    free_text_title: string | null;
    workout_date: string;
    notes: string | null;
    completed_at: string;
  }[];

  const logIds = logs.map((log) => log.id);
  const dayIds = logs.flatMap((log) =>
    log.programming_day_id ? [log.programming_day_id] : [],
  );
  const [daysResult, resultsResult, benchmarksResult, recordsResult] =
    await Promise.all([
      dayIds.length
        ? client.from("programming_days").select("id, title").in("id", dayIds)
        : emptyResult,
      logIds.length
        ? client
            .from("movement_results")
            .select(
              "id, workout_log_id, prescribed_movement_id, result_schema, weight_lb, completed_reps, duration_ms, measurement_value, measurement_unit, result_value, result_unit, completed_rounds, residual_reps",
            )
            .in("workout_log_id", logIds)
        : emptyResult,
      client
        .from("benchmarks")
        .select("id, label, comparison_direction, result_schema")
        .eq("track_id", selectedTrack.id)
        .order("label"),
      client
        .from("personal_records")
        .select(
          "id, benchmark_id, movement_result_id, value, unit, achieved_at",
        )
        .eq("user_id", memberId)
        .order("achieved_at", { ascending: false }),
    ]);
  assertSucceeded(daysResult.error);
  assertSucceeded(resultsResult.error);
  assertSucceeded(benchmarksResult.error);
  assertSucceeded(recordsResult.error);

  const results = (resultsResult.data ?? []) as ResultRow[];
  const prescribedIds = [
    ...new Set(results.map((result) => result.prescribed_movement_id)),
  ];
  const prescribedResult = prescribedIds.length
    ? await client
        .from("prescribed_movements")
        .select("id, block_id, display_name, prescription_text, display_order")
        .in("id", prescribedIds)
    : emptyResult;
  assertSucceeded(prescribedResult.error);
  const prescribed = (prescribedResult.data ?? []) as {
    id: string;
    block_id: string;
    display_name: string;
    prescription_text: string;
    display_order: number;
  }[];
  const recordRows = (recordsResult.data ?? []) as {
    id: string;
    benchmark_id: string;
    movement_result_id: string;
    value: number | string;
    unit: string;
    achieved_at: string;
  }[];
  const knownResultIds = new Set(results.map((result) => result.id));
  const missingResultIds = recordRows
    .map((record) => record.movement_result_id)
    .filter((id) => !knownResultIds.has(id));
  const olderResultsResult = missingResultIds.length
    ? await client
        .from("movement_results")
        .select(
          "id, workout_log_id, prescribed_movement_id, result_schema, weight_lb, completed_reps, duration_ms, measurement_value, measurement_unit, result_value, result_unit, completed_rounds, residual_reps",
        )
        .in("id", missingResultIds)
    : emptyResult;
  assertSucceeded(olderResultsResult.error);

  const allResultMap = new Map(
    [...results, ...((olderResultsResult.data ?? []) as ResultRow[])].map(
      (result) => [result.id, result],
    ),
  );
  const personalRecordResultIds = new Set(
    recordRows.map((record) => record.movement_result_id),
  );
  const dayMap = new Map(
    ((daysResult.data ?? []) as { id: string; title: string }[]).map((day) => [
      day.id,
      day.title,
    ]),
  );
  const prescribedMap = new Map(
    prescribed.map((movement) => [movement.id, movement]),
  );
  const benchmarkMap = new Map(
    ((benchmarksResult.data ?? []) as { id: string; label: string }[]).map(
      (benchmark) => [benchmark.id, benchmark],
    ),
  );

  return {
    member: {
      id: memberId,
      firstName: selectedMembership.firstName,
      lastName: selectedMembership.lastName,
      email: selectedMembership.email,
    },
    tracks: memberships.map((membership) => ({
      id: membership.trackId,
      code: membership.trackCode,
      name: membership.trackName,
    })),
    selectedTrack,
    workouts: logs.map((log) => ({
      id: log.id,
      date: log.workout_date,
      title: log.programming_day_id
        ? (dayMap.get(log.programming_day_id) ?? "Programmed workout")
        : (log.free_text_title ?? "Free-text workout"),
      notes: log.notes,
      completedAt: log.completed_at,
      results: results
        .filter((result) => result.workout_log_id === log.id)
        .flatMap((result) => {
          const movement = prescribedMap.get(result.prescribed_movement_id);
          if (!movement) return [];
          return [
            {
              id: result.id,
              name: movement.display_name,
              prescription: movement.prescription_text,
              value: formatResult(result),
              isPR: personalRecordResultIds.has(result.id),
            },
          ];
        }),
    })),
    personalRecords: recordRows.flatMap((record) => {
      const benchmark = benchmarkMap.get(record.benchmark_id);
      const result = allResultMap.get(record.movement_result_id);
      if (!benchmark) return [];
      return [
        {
          id: record.id,
          benchmarkId: record.benchmark_id,
          benchmarkLabel: benchmark.label,
          achievedAt: record.achieved_at,
          value: formatRecordValue(
            record.value,
            record.unit,
            result?.completed_reps,
          ),
        },
      ];
    }),
  };
}

type ResultRow = {
  id: string;
  workout_log_id: string;
  prescribed_movement_id: string;
  result_schema: string;
  weight_lb: number | string | null;
  completed_reps: number | null;
  duration_ms: number | null;
  measurement_value: number | string | null;
  measurement_unit: string | null;
  result_value: number | string | null;
  result_unit: string | null;
  completed_rounds: number | null;
  residual_reps: number | null;
};

function formatResult(result: ResultRow): string {
  switch (result.result_schema) {
    case "weighted_fixed_reps":
      return `${number(result.weight_lb)} lb`;
    case "weighted_variable_reps":
      return `${number(result.weight_lb)} lb × ${result.completed_reps} reps`;
    case "max_repetitions":
      return `${result.completed_reps} reps`;
    case "for_time":
      return duration(result.duration_ms ?? 0);
    case "height_or_distance":
      return `${number(result.measurement_value)} ${result.measurement_unit}`;
    case "calories_or_distance":
      return `${number(result.result_value)} ${result.result_unit}`;
    case "rounds_and_reps":
      return `${result.completed_rounds} rounds + ${result.residual_reps} reps`;
    default:
      return "Result unavailable";
  }
}

function formatRecordValue(
  value: number | string,
  unit: string,
  completedReps?: number | null,
): string {
  const suffix = completedReps ? ` × ${completedReps} reps` : "";
  if (unit === "lb") return `${number(value)} lb${suffix}`;
  if (unit === "ms") return duration(Number(value));
  if (unit === "rounds_reps") {
    const total = Number(value);
    return `${Math.floor(total / 100_000)} rounds + ${total % 100_000} reps`;
  }
  return `${number(value)} ${unit}`;
}

function number(value: number | string | null): string {
  return value === null
    ? "—"
    : Number(value).toLocaleString("en-US", { maximumFractionDigits: 6 });
}

function duration(milliseconds: number): string {
  const totalSeconds = Math.floor(milliseconds / 1_000);
  const hours = Math.floor(totalSeconds / 3_600);
  const minutes = Math.floor((totalSeconds % 3_600) / 60);
  const seconds = totalSeconds % 60;
  const tenths = Math.floor((milliseconds % 1_000) / 100);
  const base = hours
    ? `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
    : `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  return tenths ? `${base}.${tenths}` : base;
}

function assertSucceeded(error: QueryError): asserts error is null {
  if (error)
    throw new Error("Unable to load administrator member data.", {
      cause: error,
    });
}

const emptyResult: { data: never[]; error: null } = { data: [], error: null };
