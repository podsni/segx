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

const repoUrl = process.env.MY_SCRIPT_REPO_URL ?? "https://github.com/bangunx/scrix";

export const runCli = async (): Promise<void> => {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const scriptRoot = path.resolve(__dirname, "..", "script");
  const installLocation = process.env.MY_SCRIPT_DIR ?? scriptRoot;
  const headerContext: HeaderContext = {
    repoUrl,
    installLocation,
  };

  if (!(await pathExists(scriptRoot))) {
    logError(`Direktori script tidak ditemukan: ${scriptRoot}`);
    return;
  }

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
    const randomIndex = Math.floor(Math.random() * scriptEntries.length);
    const randomEntry = scriptEntries[randomIndex]!;
    showRandomSelection(randomEntry);

    const confirmation = await confirmExecution(scriptEntries, [randomIndex]);
    if (confirmation === "proceed") {
      await executeSelectedScripts([randomEntry], headerContext);
    }

    return false;
  }

  while (true) {
    const selectionResult = await promptScriptSelection(selection.label, scriptEntries);

    if (selectionResult.kind === "back") {
      return false;
    }

    const confirmation = await confirmExecution(scriptEntries, selectionResult.indexes);

    if (confirmation === "proceed") {
      const entriesToRun = mapEntries(selectionResult, scriptEntries);
      await executeSelectedScripts(entriesToRun, headerContext);
      return false;
    }

    // Otherwise user wants to adjust selection; loop again.
  }
};

const mapEntries = (
  selectionResult: Extract<ScriptSelectionResult, { kind: "confirmed" }>,
  scripts: ScriptEntry[]
): ScriptEntry[] =>
  selectionResult.indexes
    .map((index) => scripts[index])
    .filter((entry): entry is ScriptEntry => Boolean(entry));
