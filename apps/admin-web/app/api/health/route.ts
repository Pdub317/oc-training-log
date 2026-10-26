import type { HealthResponse } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";

export function GET() {
  const response: HealthResponse = { status: "ok" };

  return NextResponse.json(response, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
