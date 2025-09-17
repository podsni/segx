import fs from "node:fs/promises";
import path from "node:path";
import fg from "fast-glob";
import type { CategoryInfo, ScriptEntry } from "./types";
import { formatCategoryName } from "./utils";

const scriptEntryCache = new Map<string, ScriptEntry>();

export const listScriptsInDirectory = async (directory: string): Promise<string[]> => {
  const scriptPaths = await fg("*.sh", {
    cwd: directory,
    absolute: true,
    onlyFiles: true,
    unique: true,
  });
  return scriptPaths
    .map((entry) => path.normalize(entry))
    .sort((a, b) => path.basename(a).localeCompare(path.basename(b), "id-ID"));
};

export const collectCategories = async (scriptRoot: string): Promise<CategoryInfo[]> => {
  const scriptFiles = await fg("**/*.sh", {
    cwd: scriptRoot,
    absolute: true,
    onlyFiles: true,
    unique: true,
  });

  const directoryMap = new Map<
    string,
    { dirPath: string; scriptPaths: string[]; segments: string[] }
  >();

  for (const rawPath of scriptFiles) {
    const filePath = path.normalize(rawPath);
    const dirPath = path.dirname(filePath);
    const relativeDir = path.relative(scriptRoot, dirPath);

    if (!relativeDir) {
      continue;
    }

    const segments = relativeDir.split(path.sep).filter(Boolean);
    if (segments.length === 0) {
      continue;
    }

    const categoryId = segments.join("/");
    const existing = directoryMap.get(categoryId);

    if (existing) {
      existing.scriptPaths.push(filePath);
      continue;
    }

    directoryMap.set(categoryId, {
      dirPath,
      scriptPaths: [filePath],
      segments,
    });
  }

  const categories: CategoryInfo[] = Array.from(directoryMap.entries()).map(
    ([name, info]) => {
      const sortedScripts = [...info.scriptPaths].sort((a, b) =>
        path.basename(a).localeCompare(path.basename(b), "id-ID")
      );

      const displayName = info.segments.map(formatCategoryName).join(" / ");

      return {
        name,
        displayName,
        dirPath: info.dirPath,
        scriptPaths: sortedScripts,
        scriptCount: sortedScripts.length,
        depth: info.segments.length,
      };
    }
  );

  categories.sort((a, b) => a.name.localeCompare(b.name, "id-ID"));
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
