import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "../supabase/server";

export async function requireAdmin() {
  const context = await getAdminRequestContext();
  if (!context) redirect("/login");
  return context;
}

export async function getAdminRequestContext() {
  const supabase = await createSupabaseServerClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (typeof userId !== "string") return null;

  const { data: membership } = await supabase
    .from("gym_memberships")
    .select("gym_id")
    .eq("user_id", userId)
    .eq("role", "admin")
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (!membership) {
    return null;
  }

  return { supabase, userId, gymId: membership.gym_id as string };
}
