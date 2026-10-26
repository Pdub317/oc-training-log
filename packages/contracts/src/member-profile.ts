import { z } from "zod";
import { trackCodeSchema } from "./today";

const idSchema = z.uuid();

export const memberProfileSchema = z
  .object({
    member: z
      .object({
        id: idSchema,
        firstName: z.string().trim().min(1).max(100),
        lastName: z.string().trim().min(1).max(100),
        email: z.email().max(320),
        emailVerified: z.boolean(),
        timeZone: z.string().trim().min(1).max(100).nullable(),
      })
      .strict(),
    gyms: z
      .array(
        z
          .object({ id: idSchema, name: z.string().trim().min(1).max(200) })
          .strict(),
      )
      .max(20),
    tracks: z
      .array(
        z
          .object({
            id: idSchema,
            gymId: idSchema,
            gymName: z.string().trim().min(1).max(200),
            code: trackCodeSchema,
            name: z.string().trim().min(1).max(200),
            joinedAt: z.iso.datetime({ offset: true }),
          })
          .strict(),
      )
      .max(20),
  })
  .strict();

export const updateMemberProfileSchema = z
  .object({
    firstName: z.string().trim().min(1).max(100),
    lastName: z.string().trim().min(1).max(100),
    timeZone: z.string().trim().min(1).max(100),
  })
  .strict();

export const leaveTrackSchema = z
  .object({
    trackId: idSchema,
    confirmation: z.literal("leave_track"),
  })
  .strict();

export type MemberProfile = z.infer<typeof memberProfileSchema>;
export type UpdateMemberProfile = z.infer<typeof updateMemberProfileSchema>;
export type LeaveTrack = z.infer<typeof leaveTrackSchema>;
