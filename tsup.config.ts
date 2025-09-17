import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["index.ts"],
  format: ["esm"],
  splitting: false,
  sourcemap: true,
  clean: true,
  target: "node18",
  platform: "node",
  outDir: "dist",
  banner: {
    js: "#!/usr/bin/env node",
  },
});
