import fs from "node:fs/promises";
import path from "node:path";
import { embeddedScripts } from "./generated/embedded-scripts";
import { pathExists } from "./utils";

const hasExistingScripts = async (scriptRoot: string): Promise<boolean> => {
  if (!(await pathExists(scriptRoot))) {
    return false;
  }

  const entries = await fs.readdir(scriptRoot, { withFileTypes: true });
  if (entries.length === 0) {
    return false;
  }

  const hasScript = entries.some((entry) => {
    if (entry.isFile() && entry.name.endsWith(".sh")) {
      return true;
    }

    if (entry.isDirectory()) {
      return true;
    }

    return false;
  });

  return hasScript;
};

export const ensureScriptAssets = async (scriptRoot: string): Promise<void> => {
  if (embeddedScripts.length === 0) {
    return;
  }

  if (await hasExistingScripts(scriptRoot)) {
    return;
  }

  await fs.mkdir(scriptRoot, { recursive: true });

  for (const asset of embeddedScripts) {
    const targetPath = path.join(scriptRoot, asset.path);
    const directory = path.dirname(targetPath);
    await fs.mkdir(directory, { recursive: true });
    await fs.writeFile(targetPath, asset.content, "utf8");

    if (targetPath.endsWith(".sh")) {
      await fs.chmod(targetPath, 0o755);
    }
  }
};
