import fs from "node:fs/promises";
import path from "node:path";
import { embeddedScripts } from "./generated/embedded-scripts";
import { pathExists } from "./utils";

export const ensureScriptAssets = async (scriptRoot: string): Promise<void> => {
  if (embeddedScripts.length === 0) {
    return;
  }

  await fs.mkdir(scriptRoot, { recursive: true });

  for (const asset of embeddedScripts) {
    const targetPath = path.join(scriptRoot, asset.path);
    const directory = path.dirname(targetPath);
    await fs.mkdir(directory, { recursive: true });
    const exists = await pathExists(targetPath);

    const writeContent = async (): Promise<void> => {
      await fs.writeFile(targetPath, asset.content, "utf8");
      if (targetPath.endsWith(".sh")) {
        await fs.chmod(targetPath, 0o755);
      }
    };

    if (!exists) {
      await writeContent();
      continue;
    }

    try {
      const currentContent = await fs.readFile(targetPath, "utf8");
      if (currentContent === asset.content) {
        continue;
      }

      const backupPath = `${targetPath}.backup`;
      await fs.copyFile(targetPath, backupPath);
      await writeContent();
    } catch (error) {
      console.warn(`Gagal menyelaraskan skrip bawaan di ${targetPath}: ${(error as Error).message}`);
    }
  }
};
