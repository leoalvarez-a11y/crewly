# Crewly VPS Deployment Boundary

## Current authorization state

The only authorized remote boundary for Crewly is `scripts/crewly-vps-remote.ps1`, installed through the dedicated Codex execpolicy rule `crewly-vps-remote.rules`. The boundary is pinned to the current repository's absolute wrapper path and to the SSH alias `finboard-vps`. It accepts named operations and structured values only; it has no free command, host, user, or remote-path parameter.

Raw `ssh` and `scp` remain `no_match`. Arbitrary PowerShell `-Command`, `cmd /c`, a copy of the wrapper at another path, and wrappers belonging to CDNTeams or BOS are not authorized by this rule. New Crewly remote behavior must be added as a reviewed named operation with fixed or validated arguments. Shell text supplied by a user must never be forwarded or concatenated.

This boundary-preparation change does not contact or modify the VPS. The first live use must be the read-only `InspectHost` operation. It detects the effective remote user from the existing host alias; the wrapper does not permit a caller to override that user. `ConfigureService` remains fail-closed until that inspection validates the process manager and the exact service configuration path.

## Local discovery snapshot

- Git root: the repository containing this document.
- Branch at boundary creation: `feat/crewly-models-memory-layer`.
- Required source commit: `c71c536e9a27451d3657f53aefb0b3660d806d2b`.
- Fork remote: `https://github.com/leoalvarez-a11y/crewly.git`.
- Effective Codex home: `$CODEX_HOME` when set, otherwise the current user's `.codex` directory.
- Codex detected during creation: `codex-cli 0.145.0`.
- PowerShell executable detected during creation: `C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe`.
- Existing unrelated rules and wrappers are preserved. The installer writes only `rules/crewly-vps-remote.rules`.
- The configured SSH alias is `finboard-vps`; host details and credentials remain outside Git.

Crewly's native commands discovered from the checked-in CLI/package configuration are:

- build: `npm run build`;
- start: `crewly start` or the package `start` script;
- stop: `crewly stop`;
- status: `crewly status`;
- logs: `crewly logs`;
- service lifecycle: `crewly service <action>` or the selected process manager;
- health: loopback `GET /health` on the configured internal port;
- backup: `crewly backup create --out <archive>`;
- restore preview: `crewly backup restore <archive>` without `--apply`.

The final process manager, service user, proxy, TLS, and authentication configuration must be selected only after live read-only inspection. This avoids assuming that Docker, PM2, or systemd is suitable before verifying node-pty and CLI authentication constraints.

## Allowed scope

The host is fixed to `finboard-vps`. Initially approved remote paths are:

- `/opt/crewly`;
- `/opt/crewly/releases`;
- `/opt/crewly/shared`;
- `/opt/crewly/shared/crewly-home`;
- `/opt/crewly/shared/backups`;
- `/var/log/crewly`;
- `/tmp/crewly-deploy`.

Local release artifacts must remain inside this repository and under an approved Crewly path such as `dist`, `scripts`, `docs/adoption`, `evaluation-artifacts`, or versioned deployment configuration. Parent traversal, sibling-prefix matches, out-of-repository paths, and any symlink or junction in an artifact path are rejected.

The wrapper exposes only these operations:

1. `InspectHost`
2. `InspectCrewlyPrerequisites`
3. `PrepareDeploymentDryRun`
4. `UploadRelease`
5. `InstallRelease`
6. `ConfigureService`
7. `Start`
8. `Stop`
9. `Restart`
10. `Status`
11. `Health`
12. `Logs`
13. `Backup`
14. `ListBackups`
15. `RestoreDryRun`
16. `RollbackDryRun`
17. `Rollback`
18. `RunFixture`
19. `CleanupFixture`

Upload is limited to one validated `.tgz`/`.tar.gz` release beneath `/tmp/crewly-deploy`, with local and remote SHA-256 comparison. Installation creates an immutable `/opt/crewly/releases/<sha>` directory and switches `current` atomically only after a backup manifest exists. Rollback targets an existing versioned release and never deletes releases. Fixture operations use only `/tmp/crewly-deploy/fixture`. Log reads are capped at 500 lines.

## Installation and verification

Run the one-time installer from the exact repository checkout:

```powershell
& 'C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File '.\scripts\install-crewly-vps-autonomy.ps1'
```

The installer detects Codex and PowerShell, backs up the existing Codex configuration and prior Crewly rule when present, validates the candidate with the real `codex execpolicy check`, and installs only the Crewly rule. Re-running an unchanged installation is idempotent. If validation fails, the prior rule is restored. A detected managed policy stops installation without writing the rule.

Verify all effective rules with:

```powershell
& 'C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File '.\scripts\check-crewly-vps-autonomy.ps1'
```

The checker must prove that the exact Crewly wrapper is `allow` while raw SSH, raw SCP, arbitrary PowerShell, and a wrapper at another path are not allowed.

## Operational rules

Deployment, service lifecycle, health, bounded logs, native Crewly backup/restore preview, rollback, and the disposable acceptance fixture must pass through the wrapper. Secrets remain in VPS-specific environment or credential stores and must never be written to Git, command output, or deployment documentation.

Crewly's Wiki, working memory, project memory, agent memory, optional provider integrations, and all other shipped components remain present. Unconfigured optional services stay disabled by configuration only; no component is removed.
