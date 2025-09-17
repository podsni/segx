import chalk from "chalk";
import { ICONS } from "./config";

export const logInfo = (message: string): void => {
  console.log(`${chalk.blueBright(ICONS.info)} ${chalk.bold.blueBright(message)}`);
};

export const logSuccess = (message: string): void => {
  console.log(`${chalk.greenBright(ICONS.success)} ${chalk.bold.greenBright(message)}`);
};

export const logWarning = (message: string): void => {
  console.log(`${chalk.yellowBright(ICONS.warning)} ${chalk.bold.yellow(message)}`);
};

export const logError = (message: string): void => {
  console.log(`${chalk.redBright(ICONS.error)} ${chalk.bold.redBright(message)}`);
};

export const logDim = (message: string): void => {
  console.log(chalk.dim(message));
};
