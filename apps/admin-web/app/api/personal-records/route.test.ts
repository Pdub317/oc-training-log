import { describe, expect, it } from "vitest";
import type { PersonalRecordsRepository } from "../../../lib/personal-records/service";
import { createPersonalRecordsHandler } from "./route";

const track = {
  id: "00000000-0000-0000-0000-000000000202",
  code: "GP",
  name: "GP",
} as const;

describe("GET /api/personal-records", () => {
  it("returns an authorized benchmark catalog with current bests", async () => {
    const repository: PersonalRecordsRepository = {
      async list() {
        return { track, benchmarks: [] };
      },
      async detail() {
        return null;
      },
    };
    const response = await createPersonalRecordsHandler({
      async getContext() {
        return { userId: "member", repository };
      },
    })(new Request("http://localhost/api/personal-records?track=GP"));
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ track, benchmarks: [] });
  });

  it("validates identifiers before authentication and requires a session", async () => {
    let requested = false;
    const handler = createPersonalRecordsHandler({
      async getContext() {
        requested = true;
        return null;
      },
    });
    expect(
      (
        await handler(
          new Request(
            "http://localhost/api/personal-records?track=GP&benchmark=no",
          ),
        )
      ).status,
    ).toBe(400);
    expect(requested).toBe(false);
    expect(
      (
        await handler(
          new Request("http://localhost/api/personal-records?track=GP"),
        )
      ).status,
    ).toBe(401);
  });
});
