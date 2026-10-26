const requiredPublicEnvironment = [
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
] as const;

export type SupabasePublicConfig = {
  publishableKey: string;
  url: string;
};

export type SupabaseServiceConfig = {
  serviceRoleKey: string;
  url: string;
};

export function getSupabasePublicConfig(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): SupabasePublicConfig {
  const missing = requiredPublicEnvironment.filter(
    (name) => !environment[name]?.trim(),
  );

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment values: ${missing.join(", ")}`,
    );
  }

  return {
    publishableKey: environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!.trim(),
    url: environment.NEXT_PUBLIC_SUPABASE_URL!.trim(),
  };
}

export function getSupabaseServiceConfig(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): SupabaseServiceConfig {
  const url = environment.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const serviceRoleKey = environment.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const missing = [
    !url && "NEXT_PUBLIC_SUPABASE_URL",
    !serviceRoleKey && "SUPABASE_SERVICE_ROLE_KEY",
  ].filter(Boolean);
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment values: ${missing.join(", ")}`,
    );
  }
  return { url: url!, serviceRoleKey: serviceRoleKey! };
}
