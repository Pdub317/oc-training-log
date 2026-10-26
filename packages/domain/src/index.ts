export const TRACK_CODES = ["SP", "GP"] as const;

export type TrackCode = (typeof TRACK_CODES)[number];

export interface TrainingTrack {
  readonly code: TrackCode;
  readonly name: string;
}

export const TRACKS: readonly TrainingTrack[] = [
  { code: "SP", name: "Sports Performance" },
  { code: "GP", name: "General Population" },
];

export * from "./programming-import";
