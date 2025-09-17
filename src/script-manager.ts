import fs from "node:fs/promises";
import path from "node:path";
import type { CategoryInfo, ScriptEntry } from "./types";
import { formatCategoryName } from "./utils";

const scriptEntryCache = new Map<string, ScriptEntry>();

export const listScriptsInDirectory = async (directory: string): Promise<string[]> => {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".sh"))
    .map((entry) => path.join(directory, entry.name))
    .sort((a, b) => path.basename(a).localeCompare(path.basename(b), "id-ID"));
};

export const collectCategories = async (scriptRoot: string): Promise<CategoryInfo[]> => {
  const entries = await fs.readdir(scriptRoot, { withFileTypes: true });
  const categories: CategoryInfo[] = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }

    const dirPath = path.join(scriptRoot, entry.name);
    const scriptPaths = await listScriptsInDirectory(dirPath);

    if (scriptPaths.length === 0) {
      continue;
    }

    categories.push({
      name: entry.name,
      displayName: formatCategoryName(entry.name),
      dirPath,
      scriptPaths,
      scriptCount: scriptPaths.length,
    });
  }

  categories.sort((a, b) => a.displayName.localeCompare(b.displayName, "id-ID"));
  return categories;
};

export const loadScriptEntries = async (scriptPaths: string[]): Promise<ScriptEntry[]> =>
  Promise.all(scriptPaths.map(loadScriptEntry));

const loadScriptEntry = async (filePath: string): Promise<ScriptEntry> => {
  const cached = scriptEntryCache.get(filePath);
  if (cached) {
    return cached;
  }

  const content = await fs.readFile(filePath, "utf8");
  const lines = content.split(/\r?\n/);
  const description = extractDescription(lines);
  const headerSection = lines.slice(0, 5).join("\n").toLowerCase();
  const needsSudo = /(needs-sudo|require.*sudo|require.*root)/.test(headerSection);

  const entry: ScriptEntry = {
    path: filePath,
    name: path.basename(filePath),
    description,
    needsSudo,
  };

  scriptEntryCache.set(filePath, entry);
  return entry;
};

const extractDescription = (lines: string[]): string => {
  for (const line of lines.slice(0, 20)) {
    if (line.startsWith("#!")) {
      continue;
    }

    const trimmed = line.trim();
    if (trimmed === "") {
      continue;
    }

    if (trimmed.startsWith("#")) {
      return trimmed.replace(/^#+\s*/, "");
    }

    break;
  }
  return "";
};
