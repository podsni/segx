import chalk from "chalk";
import os from "node:os";
import fs from "node:fs/promises";

export const drawLine = (width: number, char = "─"): void => {
  console.log(chalk.dim(char.repeat(width)));
};

export const capitalizeWords = (value: string): string =>
  value
    .split(" ")
    .map((word) => (word ? word.charAt(0).toUpperCase() + word.slice(1) : word))
    .join(" ");

export const formatCategoryName = (value: string): string =>
  value
    .split(/[-_]/)
    .filter((part) => part.length > 0)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");

export const resolveUserName = (): string => {
  const fromEnv = process.env.SUDO_USER ?? process.env.USER ?? process.env.LOGNAME;
  if (fromEnv && fromEnv.trim()) {
    return fromEnv;
  }
  try {
    return os.userInfo().username;
  } catch {
    return "pengguna";
  }
};

export const formatDateTime = (): string => {
  const now = new Date();
  const datePart = now.toLocaleDateString("id-ID", {
    weekday: "long",
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
  const timePart = now.toLocaleTimeString("id-ID", {
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  return `${capitalizeWords(datePart)} - ${timePart}`;
};

export const pathExists = async (target: string): Promise<boolean> => {
  try {
    await fs.access(target);
    return true;
  } catch {
    return false;
  }
};
