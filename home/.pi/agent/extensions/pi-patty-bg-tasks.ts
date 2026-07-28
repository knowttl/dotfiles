import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const PATTY_SHORTCUT = "ctrl+shift+x";
const REMAPPED_SHORTCUT = "ctrl+alt+x";

export default async function registerPattyWithRemappedShortcut(
  pi: ExtensionAPI,
): Promise<void> {
  const extensionPath = join(
    homedir(),
    ".pi/agent/npm/node_modules/pi-patty-bg-tasks/index.ts",
  );
  const { default: registerPatty } = (await import(
    pathToFileURL(extensionPath).href
  )) as { default: (api: ExtensionAPI) => void | Promise<void> };

  const remappedApi = new Proxy(pi, {
    get(target, property) {
      if (property === "registerShortcut") {
        return (
          shortcut: Parameters<ExtensionAPI["registerShortcut"]>[0],
          options: Parameters<ExtensionAPI["registerShortcut"]>[1],
        ) =>
          target.registerShortcut(
            shortcut === PATTY_SHORTCUT ? REMAPPED_SHORTCUT : shortcut,
            options,
          );
      }

      const value = Reflect.get(target, property, target) as unknown;
      return typeof value === "function" ? value.bind(target) : value;
    },
  });

  await registerPatty(remappedApi);
}
