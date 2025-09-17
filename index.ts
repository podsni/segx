#!/usr/bin/env bun
import { runCli } from "./src/cli";

runCli().catch((error) => {
  console.error(error);
  process.exit(1);
});
