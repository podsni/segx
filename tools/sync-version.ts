import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const versionFile = path.join(projectRoot, "VERSION");
const packageJsonFile = path.join(projectRoot, "package.json");

const readVersion = async (): Promise<string> => {
  const raw = await fs.readFile(versionFile, "utf8");
  const value = raw.trim();
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z-.]+)?$/.test(value)) {
    throw new Error(`Nilai versi '${value}' tidak valid. Gunakan format semver, mis. 1.2.3 atau 1.2.3-beta.1`);
  }
  return value;
};

const updatePackageJson = async (version: string): Promise<void> => {
  const raw = await fs.readFile(packageJsonFile, "utf8");
  const pkg = JSON.parse(raw) as { version?: string };

  if (pkg.version === version) {
    console.log(`Versi package.json sudah ${version}`);
    return;
  }

  pkg.version = version;
  const updated = JSON.stringify(pkg, null, 2) + "\n";
  await fs.writeFile(packageJsonFile, updated, "utf8");
  console.log(`Versi package.json diperbarui menjadi ${version}`);
};

const main = async (): Promise<void> => {
  const version = await readVersion();
  await updatePackageJson(version);
};

main().catch((error) => {
  console.error("Gagal sinkronisasi versi:", error);
  process.exit(1);
});
