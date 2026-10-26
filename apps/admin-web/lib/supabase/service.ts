import { createClient } from "@supabase/supabase-js";
import { getSupabaseServiceConfig } from "./config";

export function createSupabaseServiceClient() {
  const config = getSupabaseServiceConfig();
  return createClient(config.url, config.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
