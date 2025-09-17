import fs from "node:fs/promises";
import type { Dirent } from "node:fs";
import path from "node:path";
import type { CategoryInfo, ScriptEntry } from "./types";
import { formatCategoryName } from "./utils";

const scriptEntryCache = new Map<string, ScriptEntry>();

export const listScriptsInDirectory = async (directory: string): Promise<string[]> => {
  try {
    const entries = await fs.readdir(directory, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".sh"))
      .map((entry) => path.join(directory, entry.name))
      .sort((a, b) => path.basename(a).localeCompare(path.basename(b), "id-ID"));
  } catch {
    return [];
  }
};

export const collectCategories = async (scriptRoot: string): Promise<CategoryInfo[]> => {
  const categories: CategoryInfo[] = [];

  await walkDirectories(scriptRoot, [], categories);

  categories.sort((a, b) => a.name.localeCompare(b.name, "id-ID"));
  return categories;
};

const walkDirectories = async (
  currentDir: string,
  segments: string[],
  categories: CategoryInfo[]
): Promise<void> => {
  let entries: Dirent[];
  try {
    entries = await fs.readdir(currentDir, { withFileTypes: true });
  } catch {
    return;
  }

  const fileEntries = entries.filter((entry) => entry.isFile() && entry.name.endsWith(".sh"));
  const dirEntries = entries.filter((entry) => entry.isDirectory());

  if (fileEntries.length > 0 && segments.length > 0) {
    const scriptPaths = fileEntries
      .map((entry) => path.join(currentDir, entry.name))
      .sort((a, b) => path.basename(a).localeCompare(path.basename(b), "id-ID"));

    const name = segments.join("/");
    const displayName = segments.map(formatCategoryName).join(" / ");

    categories.push({
      name,
      displayName,
      dirPath: currentDir,
      scriptPaths,
      scriptCount: scriptPaths.length,
      depth: segments.length,
    });
  }

  for (const dir of dirEntries) {
    await walkDirectories(path.join(currentDir, dir.name), [...segments, dir.name], categories);
  }
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
