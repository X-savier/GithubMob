import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["contract/**/*.spec.{js,ts}"],
    environment: "node",
    testTimeout: 30_000,
    hookTimeout: 30_000,
    fileParallelism: false,
    sequence: { concurrent: false },
    reporters: ["verbose"],
  },
});
