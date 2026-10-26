import ExcelJS from "exceljs";
import mammoth from "mammoth";

export type ProgrammingSourceType = "paste" | "text" | "word" | "spreadsheet";

export class UnsupportedProgrammingFileError extends Error {}

const textExtensions = new Set(["txt", "md", "csv", "tsv"]);
const wordExtensions = new Set(["docx"]);
const spreadsheetExtensions = new Set(["xlsx"]);

export async function extractProgrammingSource(input: {
  pastedText: string;
  file: File | null;
}): Promise<{
  sourceText: string;
  sourceType: ProgrammingSourceType;
  sourceFileName: string | null;
}> {
  const pastedText = input.pastedText.trim();
  if (!input.file || input.file.size === 0) {
    if (!pastedText) throw new UnsupportedProgrammingFileError("empty_source");
    return {
      sourceText: pastedText,
      sourceType: "paste",
      sourceFileName: null,
    };
  }

  if (input.file.size > 5_000_000) {
    throw new UnsupportedProgrammingFileError("file_too_large");
  }

  const extension = input.file.name.split(".").pop()?.toLowerCase() ?? "";
  if (textExtensions.has(extension)) {
    const fileText = await input.file.text();
    const sourceText =
      extension === "csv" || extension === "tsv"
        ? flattenDelimitedText(fileText, extension === "tsv" ? "\t" : ",")
        : fileText.trim();
    if (!sourceText) throw new UnsupportedProgrammingFileError("empty_source");
    return {
      sourceText,
      sourceType:
        extension === "csv" || extension === "tsv" ? "spreadsheet" : "text",
      sourceFileName: input.file.name,
    };
  }

  const buffer = Buffer.from(await input.file.arrayBuffer());
  if (wordExtensions.has(extension)) {
    const extracted = await mammoth.extractRawText({ buffer });
    if (!extracted.value.trim()) {
      throw new UnsupportedProgrammingFileError("empty_source");
    }
    return {
      sourceText: extracted.value.trim(),
      sourceType: "word",
      sourceFileName: input.file.name,
    };
  }

  if (spreadsheetExtensions.has(extension)) {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer as never);
    const sheets: string[] = [];
    workbook.eachSheet((sheet) => {
      const cells: string[] = [];
      sheet.eachRow({ includeEmpty: true }, (row) => {
        const values = Array.isArray(row.values) ? row.values.slice(1) : [];
        cells.push(
          ...values
            .map(formatCell)
            .map((value) => value.trim())
            .filter(Boolean),
        );
      });
      sheets.push(cells.join("\n").trim());
    });
    const sourceText = sheets.filter(Boolean).join("\n\n").trim();
    if (!sourceText) throw new UnsupportedProgrammingFileError("empty_source");
    return {
      sourceText,
      sourceType: "spreadsheet",
      sourceFileName: input.file.name,
    };
  }

  throw new UnsupportedProgrammingFileError("unsupported_file_type");
}

function flattenDelimitedText(source: string, delimiter: string) {
  const cells: string[] = [];
  let cell = "";
  let quoted = false;
  for (let index = 0; index < source.length; index += 1) {
    const character = source[index]!;
    if (character === '"') {
      if (quoted && source[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (
      !quoted &&
      (character === delimiter || character === "\n" || character === "\r")
    ) {
      if (cell.trim()) cells.push(cell.trim());
      cell = "";
      if (character === "\r" && source[index + 1] === "\n") index += 1;
    } else {
      cell += character;
    }
  }
  if (cell.trim()) cells.push(cell.trim());
  return cells.join("\n");
}

function formatCell(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "object") {
    const cell = value as {
      text?: unknown;
      result?: unknown;
      richText?: { text?: unknown }[];
    };
    if (cell.text !== undefined) return String(cell.text);
    if (cell.result !== undefined) return String(cell.result);
    if (cell.richText)
      return cell.richText.map((part) => String(part.text ?? "")).join("");
  }
  return String(value);
}
