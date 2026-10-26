import { describe, expect, it } from "vitest";
import { TRACKS } from "./index";

describe("training tracks", () => {
  it("keeps Sports Performance and General Population distinct", () => {
    expect(TRACKS.map(({ code }) => code)).toEqual(["SP", "GP"]);
    expect(new Set(TRACKS.map(({ code }) => code)).size).toBe(TRACKS.length);
  });
});
