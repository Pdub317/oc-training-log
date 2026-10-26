import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import {
  extractProgrammingSource,
  UnsupportedProgrammingFileError,
} from "./source-extraction";

describe("programming source extraction", () => {
  it("accepts pasted programming without a file", async () => {
    await expect(
      extractProgrammingSource({
        pastedText: "September 8\nStrength: 5x5",
        file: null,
      }),
    ).resolves.toMatchObject({ sourceType: "paste", sourceFileName: null });
  });

  it("flattens CSV cells so dates and block headings remain parseable", async () => {
    const file = new File(
      [
        '"Tuesday, September 8, 2026","Strength: 5x5 Back Squat","WOD: For time"',
      ],
      "programming.csv",
      { type: "text/csv" },
    );
    const extracted = await extractProgrammingSource({ pastedText: "", file });
    expect(extracted.sourceText).toBe(
      "Tuesday, September 8, 2026\nStrength: 5x5 Back Squat\nWOD: For time",
    );
    expect(extracted.sourceType).toBe("spreadsheet");
  });

  it("reads each populated Excel cell in workbook order", async () => {
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet("September");
    sheet.addRow(["2026-09-08", "Strength: 5x5 Back Squat"]);
    const bytes = await workbook.xlsx.writeBuffer();
    const file = new File([bytes as BlobPart], "programming.xlsx");
    const extracted = await extractProgrammingSource({ pastedText: "", file });
    expect(extracted.sourceText).toBe("2026-09-08\nStrength: 5x5 Back Squat");
  });

  it("rejects unsupported file types", async () => {
    await expect(
      extractProgrammingSource({
        pastedText: "",
        file: new File(["x"], "source.pdf"),
      }),
    ).rejects.toBeInstanceOf(UnsupportedProgrammingFileError);
  });
});
