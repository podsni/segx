export type ScriptEntry = {
  path: string;
  name: string;
  description: string;
  needsSudo: boolean;
};

export type HeaderContext = {
  repoUrl: string;
  installLocation: string;
};

export type CategoryInfo = {
  name: string;
  displayName: string;
  dirPath: string;
  scriptPaths: string[];
  scriptCount: number;
  depth: number;
};

export type CategorySelection =
  | { kind: "all"; label: string; scriptPaths: string[] }
  | { kind: "random"; label: string; scriptPaths: string[] }
  | { kind: "category"; label: string; scriptPaths: string[] }
  | { kind: "exit" };

export type SelectionResult = "executed" | "back" | "exit";

export type ConfirmationResult = "executed" | "backToSelection" | "backToCategory" | "exit";
