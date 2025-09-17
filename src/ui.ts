import chalk from "chalk";
import {
  confirm,
  intro,
  isCancel,
  log,
  multiselect,
  note,
  outro,
  select,
} from "@clack/prompts";
import { ASCII_ART, ICONS } from "./config";
import type {
  CategoryInfo,
  CategorySelection,
  HeaderContext,
  ScriptEntry,
} from "./types";
import { formatDateTime, resolveUserName } from "./utils";

export type ScriptSelectionResult =
  | { kind: "confirmed"; indexes: number[] }
  | { kind: "back" };

export const showIntro = (
  context: HeaderContext,
  stats: { categories: number; totalScripts: number; rootScripts: number }
): void => {
  console.clear();
  console.log(chalk.cyanBright(ASCII_ART));
  intro(`Selamat datang, ${resolveUserName()}! ${ICONS.rocket}`);

  const facts: string[] = [
    `${chalk.cyan("Repository")}: ${chalk.bold(context.repoUrl)}`,
    `${chalk.cyan("Lokasi Instalasi")}: ${chalk.bold(context.installLocation)}`,
    `${chalk.cyan("Tanggal")}: ${chalk.bold(formatDateTime())}`,
    `${chalk.cyan("Total Kategori")}: ${chalk.bold(stats.categories)}`,
    `${chalk.cyan("Total Skrip")}: ${chalk.bold(stats.totalScripts)}`,
  ];

  if (stats.rootScripts > 0) {
    facts.push(`${chalk.cyan("Skrip Root")}: ${chalk.bold(stats.rootScripts)}`);
  }

  note(facts.join("\n"), "Informasi repositori");
};

export const promptCategorySelection = async (
  categories: CategoryInfo[],
  rootScriptPaths: string[],
  allScriptPaths: string[],
  totalScripts: number
): Promise<CategorySelection> => {
  const options = [
    {
      value: "all",
      label: "Semua Skrip",
      hint: `Gabungkan ${totalScripts} skrip dari seluruh kategori`,
    },
    {
      value: "random",
      label: "Random",
      hint: "Pilih 1 skrip acak dari semua kategori",
      disabled: allScriptPaths.length === 0,
    },
  ];

  if (rootScriptPaths.length > 0) {
    options.push({
      value: "__root",
      label: "Skrip Root",
      hint: `${rootScriptPaths.length} skrip di level root`,
    });
  }

  categories.forEach((category) => {
    options.push({
      value: category.name,
      label: category.displayName,
      hint: `${category.scriptCount} skrip`,
    });
  });

  options.push({
    value: "exit",
    label: "Keluar",
    hint: "Tutup aplikasi",
  });

  const choice = await select({
    message: "Pilih kategori atau mode eksekusi",
    options,
  });

  if (isCancel(choice) || choice === "exit") {
    return { kind: "exit" };
  }
  if (choice === "all") {
    return { kind: "all", label: "Semua Skrip", scriptPaths: allScriptPaths };
  }
  if (choice === "random") {
    return { kind: "random", label: "Random", scriptPaths: allScriptPaths };
  }
  if (choice === "__root") {
    return { kind: "category", label: "Skrip Root", scriptPaths: rootScriptPaths };
  }

  const category = categories.find((item) => item.name === choice);
  if (!category) {
    log.error("Pilihan kategori tidak valid.");
    return { kind: "exit" };
  }

  return {
    kind: "category",
    label: category.displayName,
    scriptPaths: category.scriptPaths,
  };
};

export const promptScriptSelection = async (
  label: string,
  scripts: ScriptEntry[]
): Promise<ScriptSelectionResult> => {
  const selection = await multiselect<number>({
    message: `Pilih skrip dari ${label}`,
    options: scripts.map((script, index) => ({
      value: index,
      label: script.name,
      hint: script.description || undefined,
    })),
    required: true,
  });

  if (isCancel(selection)) {
    return { kind: "back" };
  }

  if (!Array.isArray(selection) || selection.length === 0) {
    log.warn("Belum ada skrip yang dipilih.");
    return { kind: "back" };
  }

  return { kind: "confirmed", indexes: selection };
};

export const confirmExecution = async (
  scripts: ScriptEntry[],
  selectedIndexes: number[]
): Promise<"proceed" | "backToSelection"> => {
  const selectedEntries = selectedIndexes
    .map((index) => scripts[index])
    .filter((entry): entry is ScriptEntry => Boolean(entry));

  if (selectedEntries.length === 0) {
    log.warn("Tidak ada skrip valid yang dipilih.");
    return "backToSelection";
  }

  const items = selectedEntries
    .map((entry) => {
      const details = entry.description ? ` - ${entry.description}` : "";
      return `- ${entry.name}${details}`;
    })
    .join("\n");

  note(items, "Skrip yang akan dijalankan");

  const confirmation = await confirm({
    message: "Jalankan skrip yang dipilih sekarang?",
  });

  if (isCancel(confirmation)) {
    return "backToSelection";
  }

  if (!confirmation) {
    log.info("Eksekusi dibatalkan.");
    return "backToSelection";
  }

  return "proceed";
};

export const showRandomSelection = (entry: ScriptEntry): void => {
  log.info(`Mode random memilih skrip: ${chalk.bold(entry.name)}`);
};

export const showOutro = (): void => {
  outro("Sampai jumpa lagi! ✨");
};
