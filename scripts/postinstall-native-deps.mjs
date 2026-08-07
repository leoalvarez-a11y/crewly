/**
 * Refresh native dependencies without relying on POSIX shell syntax.
 * Each rebuild is best-effort to preserve the previous install contract while
 * allowing npm install to work in cmd.exe, PowerShell, and POSIX shells.
 */

import { spawnSync } from 'node:child_process';

const npmCli = process.env.npm_execpath;
const packages = ['node-pty', 'better-sqlite3'];

for (const packageName of packages) {
  if (!npmCli) {
    console.warn(`[postinstall] npm_execpath is unavailable; skipped ${packageName}.`);
    continue;
  }
  const result = spawnSync(process.execPath, [npmCli, 'rebuild', packageName], {
    stdio: 'inherit',
    shell: false,
  });
  if (result.status !== 0) {
    console.warn(`[postinstall] Optional rebuild failed for ${packageName}.`);
  }
}
