import { describe, expect, it } from "vitest";
import {
  importedMovementDraftSchema,
  programmingImportDraftSchema,
} from "./programming-import";

describe("programmingImportDraftSchema", () => {
  it("rejects empty programming days and unresolved shape changes", () => {
    expect(
      programmingImportDraftSchema.safeParse({
        trackCode: "GP",
        sourceText: "September programming",
        days: [],
        warnings: [],
      }).success,
    ).toBe(false);
  });

  it("requires option group keys and labels together", () => {
    const base = {
      id: "movement-1",
      displayName: "1k Row",
      prescriptionText: "1k row for time",
      coachNotes: "",
      resultSchema: "for_time",
      confidence: "high",
      requiresReview: false,
      warnings: [],
    };

    expect(
      importedMovementDraftSchema.safeParse({
        ...base,
        optionGroupKey: "test-options",
        optionGroupLabel: "Select completed options",
      }).success,
    ).toBe(true);
    expect(
      importedMovementDraftSchema.safeParse({
        ...base,
        optionGroupKey: "test-options",
      }).success,
    ).toBe(false);
  });
});
