import { describe, expect, it } from "vitest";
import { programmingImportDraftSchema } from "@oc-training-log/contracts";
import { parseProgrammingSource } from "@oc-training-log/domain";

describe("parser review contract", () => {
  for (const trackCode of ["SP", "GP"] as const) {
    for (const section of ["Strength", "Accessory"]) {
      it.each(["", "N/A", "n/a", "  n/A  "])(
        `${trackCode} ${section} displays %j as unscored N/A`,
        (value) => {
          const sourceText = `September 19, 2026\n${section}: ${value}`;
          const draft = parseProgrammingSource({
            sourceText,
            trackCode,
            defaultYear: 2026,
          });
          expect(programmingImportDraftSchema.safeParse(draft).success).toBe(
            true,
          );
          expect(draft.days[0]?.blocks[0]?.movements).toEqual([
            expect.objectContaining({
              displayName: "N/A",
              prescriptionText: "N/A",
              resultSchema: "notes_only",
              requiresReview: false,
            }),
          ]);
          expect(draft.sourceText).toBe(sourceText.trim());
        },
      );
    }
  }

  it.each(["SP", "GP"] as const)(
    "opens %s drafts with blank section headings",
    (trackCode) => {
      const sourceText =
        "September 19, 2026\nStrength: 3x5 Back Squat\nAccessory:\nWod: 500m row for time\nRecovery:";
      const draft = parseProgrammingSource({
        sourceText,
        trackCode,
        defaultYear: 2026,
      });
      expect(programmingImportDraftSchema.safeParse(draft).success).toBe(true);
      expect(draft.days[0]?.blocks.map((block) => block.type)).toEqual([
        "strength",
        "accessory",
        "wod",
      ]);
      expect(draft.days[0]?.sourceExcerpt).toBe(sourceText);
    },
  );
  it("retains exercises supplied below their section heading", () => {
    const draft = parseProgrammingSource({
      sourceText: "September 19, 2026\nAccessory:\n3x10 DB Row",
      trackCode: "GP",
      defaultYear: 2026,
    });
    expect(programmingImportDraftSchema.safeParse(draft).success).toBe(true);
    expect(draft.days[0]?.blocks[0]?.movements[0]?.prescriptionText).toBe(
      "3x10 DB Row",
    );
  });
  it("rejects entirely empty workout days before persistence", () => {
    const draft = parseProgrammingSource({
      sourceText: "September 19, 2026\nRecovery:",
      trackCode: "GP",
      defaultYear: 2026,
    });
    expect(programmingImportDraftSchema.safeParse(draft).success).toBe(false);
  });
});
