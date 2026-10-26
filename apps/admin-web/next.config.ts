import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  agentRules: false,
  poweredByHeader: false,
  reactStrictMode: true,
  transpilePackages: ["@oc-training-log/contracts", "@oc-training-log/domain"],
};

export default nextConfig;
