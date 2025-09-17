import chalk from "chalk";
import fs from "node:fs/promises";
import { confirm, isCancel, log, note, spinner, text } from "@clack/prompts";
import type { HeaderContext, ScriptEntry } from "./types";
import { drawLine, formatDateTime } from "./utils";
import { logError, logInfo, logSuccess, logWarning } from "./logger";

export const executeSelectedScripts = async (
  entries: ScriptEntry[],
  headerContext: HeaderContext
): Promise<void> => {
  renderExecutionIntro(entries.length, headerContext);

  if (!(await checkSudoRequirements(entries))) {
    logError("Tidak dapat melanjutkan tanpa akses sudo yang diperlukan.");
    await waitForAcknowledgement("Tekan Enter untuk kembali ke menu utama...");
    return;
  }

  const succeeded: ScriptEntry[] = [];
  const failed: ScriptEntry[] = [];
  const overallStart = Date.now();

  for (let i = 0; i < entries.length; i += 1) {
    const entry = entries[i]!;
    log.step(`Menjalankan [${i + 1}/${entries.length}] ${entry.name}`);
    const success = await executeSingleScript(entry);

    if (success) {
      succeeded.push(entry);
    } else {
      failed.push(entry);
      if (i < entries.length - 1) {
        const shouldContinue = await confirm({
          message: "Lanjutkan ke skrip berikutnya?",
          initialValue: true,
        });

        if (isCancel(shouldContinue) || shouldContinue === false) {
          logInfo("Eksekusi dihentikan oleh pengguna.");
          break;
        }
      }
    }
  }

  const totalDuration = Math.max(0, Math.round((Date.now() - overallStart) / 1000));
  await showExecutionSummary(totalDuration, succeeded, failed);
  await waitForAcknowledgement("Tekan Enter untuk kembali ke menu utama...");
};

const renderExecutionIntro = (total: number, context: HeaderContext): void => {
  console.log();
  log.info("Menyiapkan eksekusi skrip...");
  note(
    [
      `${chalk.cyan("Total skrip")}: ${chalk.bold(total)}`,
      `${chalk.cyan("Lokasi")}: ${chalk.bold(context.installLocation)}`,
      `${chalk.cyan("Repository")}: ${chalk.bold(context.repoUrl)}`,
      `${chalk.cyan("Mulai")}: ${chalk.bold(formatDateTime())}`,
    ].join("\n"),
    "Rincian eksekusi"
  );
};

const executeSingleScript = async (entry: ScriptEntry): Promise<boolean> => {
  const headerLabel = ` MENJALANKAN: ${entry.name.padEnd(30)}`;
  console.log(chalk.bgBlue.white.bold(headerLabel));
  drawLine(75);

  try {
    await fs.chmod(entry.path, 0o755);
  } catch {
    // abaikan kegagalan chmod; eksekusi akan menentukan keberhasilan
  }

  const command = entry.needsSudo ? ["sudo", "bash", entry.path] : ["bash", entry.path];
  const commandLabel = entry.needsSudo ? "sudo bash" : "bash";
  console.log(chalk.dim(`Perintah: ${commandLabel} "${entry.path}"`));
  drawLine(75, "·");

  try {
    const subprocess = Bun.spawn({
      cmd: command,
      stdout: "inherit",
      stderr: "inherit",
      stdin: "inherit",
    });

    const exitCode = await subprocess.exited;
    drawLine(75);

    if (exitCode === 0) {
      logSuccess(`Skrip '${entry.name}' berhasil dijalankan.`);
      return true;
    }

    logError(`Skrip '${entry.name}' gagal dijalankan (exit code: ${exitCode}).`);
    return false;
  } catch (error) {
    drawLine(75);
    logError(`Gagal menjalankan skrip '${entry.name}': ${(error as Error).message}`);
    return false;
  }
};

const checkSudoRequirements = async (entries: ScriptEntry[]): Promise<boolean> => {
  if (!entries.some((entry) => entry.needsSudo)) {
    return true;
  }

  logWarning("Beberapa skrip memerlukan hak akses root (sudo).");
  const spin = spinner();
  spin.start("Meminta akses sudo...");

  try {
    const subprocess = Bun.spawn({
      cmd: ["sudo", "-v"],
      stdout: "inherit",
      stderr: "inherit",
      stdin: "inherit",
    });

    const exitCode = await subprocess.exited;
    if (exitCode !== 0) {
      spin.stop("Gagal memperoleh akses sudo.");
      return false;
    }

    spin.stop("Hak akses sudo berhasil diperoleh.");
    logSuccess("Hak akses sudo aktif.");
    return true;
  } catch (error) {
    spin.stop("Gagal memperoleh akses sudo.");
    logError(`Gagal menginisiasi permintaan sudo: ${(error as Error).message}`);
    return false;
  }
};

const showExecutionSummary = async (
  totalDuration: number,
  succeeded: ScriptEntry[],
  failed: ScriptEntry[]
): Promise<void> => {
  const lines: string[] = [
    `${chalk.cyan("Total waktu")}: ${chalk.bold(`${totalDuration} detik`)}`,
    `${chalk.cyan("Berhasil")}: ${chalk.greenBright.bold(succeeded.length)}`,
    `${chalk.cyan("Gagal")}: ${chalk.redBright.bold(failed.length)}`,
  ];

  if (succeeded.length > 0) {
    lines.push("", chalk.greenBright("Skrip Berhasil:"));
    succeeded.forEach((entry) => lines.push(`  ${chalk.greenBright("✓")} ${entry.name}`));
  }

  if (failed.length > 0) {
    lines.push("", chalk.redBright("Skrip Gagal:"));
    failed.forEach((entry) => lines.push(`  ${chalk.redBright("✗")} ${entry.name}`));
  }

  note(lines.join("\n"), "Ringkasan eksekusi");

  if (failed.length === 0) {
    logSuccess("Semua skrip berhasil dijalankan!");
  } else {
    logWarning("Beberapa skrip mengalami masalah saat eksekusi.");
  }
};

const waitForAcknowledgement = async (message: string): Promise<void> => {
  await text({ message, placeholder: "Tekan Enter", defaultValue: "" });
};
