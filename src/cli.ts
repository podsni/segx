import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pathExists } from "./utils";
import { collectCategories, listScriptsInDirectory, loadScriptEntries } from "./script-manager";
import { logError, logInfo, logSuccess, logWarning } from "./logger";
import {
  confirmExecution,
  promptCategorySelection,
  promptScriptSelection,
  showIntro,
  showOutro,
  showRandomSelection,
} from "./ui";
import type { ScriptSelectionResult } from "./ui";
import type { CategorySelection, HeaderContext, ScriptEntry } from "./types";
import { executeSelectedScripts } from "./executor";
import { ensureScriptAssets } from "./asset-manager";

const repoUrl = process.env.MY_SCRIPT_REPO_URL ?? "https://github.com/podsni/segx";

export const runCli = async (): Promise<void> => {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const envDir = process.env.MY_SCRIPT_DIR?.trim();
  const packageScriptRoot = path.resolve(__dirname, "..", "script");
  const userScriptRoot = path.join(os.homedir(), ".segx", "script");
  const candidateRoots = envDir ? [path.resolve(envDir)] : [packageScriptRoot, userScriptRoot];

  let scriptRoot: string | null = null;

  for (const candidate of candidateRoots) {
    try {
      const isPackageCandidate = !envDir && candidate === packageScriptRoot;
      if (isPackageCandidate && !(await pathExists(candidate))) {
        // Paket global tidak menyertakan direktori script; gunakan fallback.
        continue;
      }

      await ensureScriptAssets(candidate);
      if (await pathExists(candidate)) {
        scriptRoot = candidate;
        break;
      }
    } catch (error) {
      logWarning(`Gagal menyiapkan direktori script di ${candidate}: ${(error as Error).message}`);
    }
  }

  if (!scriptRoot) {
    logError("Direktori script tidak dapat dipersiapkan. Periksa konfigurasi MY_SCRIPT_DIR atau hak akses sistem.");
    return;
  }

  const installLocation = scriptRoot;
  const headerContext: HeaderContext = {
    repoUrl,
    installLocation,
  };

  process.on("SIGINT", () => {
    logWarning("Eksekusi dibatalkan oleh pengguna");
    showOutro();
    process.exit(130);
  });

  while (true) {
    const rootScriptPaths = await listScriptsInDirectory(scriptRoot);
    const categories = await collectCategories(scriptRoot);
    const totalScripts = rootScriptPaths.length + categories.reduce((sum, cat) => sum + cat.scriptCount, 0);
    const allScriptPaths = [...rootScriptPaths, ...categories.flatMap((cat) => cat.scriptPaths)].sort((a, b) =>
      path.basename(a).localeCompare(path.basename(b), "id-ID")
    );

    showIntro(headerContext, {
      categories: categories.length,
      totalScripts,
      rootScripts: rootScriptPaths.length,
    });

    if (allScriptPaths.length === 0) {
      logWarning("Tidak ada skrip .sh ditemukan di direktori 'script'.");
      showOutro();
      break;
    }

    const selection = await promptCategorySelection(
      categories,
      rootScriptPaths,
      allScriptPaths,
      totalScripts
    );

    const exitRequested = await handleCategorySelection(selection, headerContext);
    if (exitRequested) {
      break;
    }
  }

  logSuccess("Terima kasih telah menggunakan HADES Script Manager!");
  logInfo("Dibuat dengan ❤️  untuk memudahkan pengelolaan skrip");
};

const handleCategorySelection = async (
  selection: CategorySelection,
  headerContext: HeaderContext
): Promise<boolean> => {
  if (selection.kind === "exit") {
    showOutro();
    return true;
  }

  const scriptEntries = await loadScriptEntries(selection.scriptPaths);

  if (scriptEntries.length === 0) {
    logWarning("Kategori yang dipilih belum memiliki skrip.");
    return false;
  }

  if (selection.kind === "random") {
    while (true) {
      const randomIndex = Math.floor(Math.random() * scriptEntries.length);
      const randomEntry = scriptEntries[randomIndex]!;
      showRandomSelection(randomEntry);

      const confirmation = await confirmExecution(scriptEntries, [randomIndex]);

      if (confirmation === "proceed") {
        await executeSelectedScripts([randomEntry], headerContext);
        return false;
      }

      if (confirmation === "backToCategory") {
        return false;
      }

      if (confirmation === "exit") {
        showOutro();
        return true;
      }

      // backToSelection -> pilih ulang skrip random
    }
  }

  let previousSelection: number[] = [];

  while (true) {
    const selectionResult = await promptScriptSelection(
      selection.label,
      scriptEntries,
      previousSelection
    );

    if (selectionResult.kind === "back") {
      return false;
    }

    previousSelection = [...selectionResult.indexes];

    const confirmation = await confirmExecution(scriptEntries, selectionResult.indexes);

    if (confirmation === "proceed") {
      const entriesToRun = mapEntries(selectionResult, scriptEntries);
      await executeSelectedScripts(entriesToRun, headerContext);
      return false;
    }

    if (confirmation === "backToCategory") {
      return false;
    }

    if (confirmation === "exit") {
      showOutro();
      return true;
    }

    // Otherwise user wants to menyesuaikan pilihan; ulangi loop
  }
};

const mapEntries = (
  selectionResult: Extract<ScriptSelectionResult, { kind: "confirmed" }>,
  scripts: ScriptEntry[]
): ScriptEntry[] =>
  selectionResult.indexes
    .map((index) => scripts[index])
    .filter((entry): entry is ScriptEntry => Boolean(entry));
