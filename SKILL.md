---
name: windows-dev-disk-audit
description: Diagnose Windows system-drive pressure for developers using WSL, VS Code, Codex, Claude Code, Docker, Node/Python/Rust tooling, browsers, and cloud-sync folders. Use this skill whenever a Windows user asks what is filling C:, whether WSL swap or ext4.vhdx is responsible, how much developer cache is reclaimable, or wants a safe disk-usage report. Prefer the bundled read-only scanner, distinguish logical size from allocated size, and never delete data without separate explicit approval.
compatibility: Windows PowerShell 5.1+ or PowerShell 7; robocopy.exe; optional wsl.exe and Docker inside WSL.
---

# Windows Developer Disk Audit

Use this workflow to explain Windows disk pressure accurately and safely. Developer workstations often combine sparse VHDX files, cloud placeholders, Windows virtual memory, browser service-worker storage, duplicated editor runtimes, and rebuildable package caches. A useful report separates those categories instead of treating every large path as disposable.

## Safety contract

- Run read-only inspection first. The bundled scanner writes only its report files under the selected output directory.
- Do not delete, prune, compact, uninstall, change page-file settings, disable hibernation, or stop running workloads unless the user separately approves that action.
- Treat `pagefile.sys`, `hiberfil.sys`, WSL VHDX files, editor state, browser profiles, Docker volumes, and cloud-sync folders as stateful data—not ordinary cache.
- Resolve exact paths before proposing destructive commands. Never use broad recursive deletion against a profile root, drive root, `%LOCALAPPDATA%`, `%APPDATA%`, or a WSL root filesystem.
- A stopped WSL distribution should remain stopped unless the user approves runtime inspection. `-InspectWslRuntime` is opt-in because it starts distributions temporarily.

## Standard workflow

1. Run the scanner in `Fast` mode.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsDevDiskAudit.ps1 -Mode Fast -OutputDirectory .\audit-output
   ```

2. Read both `windows-dev-disk-audit.md` and `windows-dev-disk-audit.json`. The Markdown file is the user-facing report; JSON preserves raw values for follow-up automation.
3. If the first pass does not explain most used space, run `Full` mode. It scans top-level directories on the selected drive and can take several minutes.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsDevDiskAudit.ps1 -Mode Full -OutputDirectory .\audit-output-full
   ```

4. If WSL internals or Docker reclaimability matter, ask permission to start WSL, then add `-InspectWslRuntime`.
5. Interpret results using the classifications below. Do not add overlapping directory totals together; `AppData`, its children, and named caches may describe the same bytes at different levels.
6. Present findings using the exact report structure in `references/report-format.md`. Use `examples/example-report.md` as the formatting example, not as factual data.

## Interpretation rules

### WSL

- `ext4.vhdx` is the Linux filesystem container, not swap. Compare its allocated size with Linux `df` output when runtime inspection is authorized.
- WSL swap is typically a separate temporary VHD/device. Report configured/active swap and actual usage; do not blame swap merely because WSL is present.
- Deleting files inside WSL usually does not shrink the Windows VHDX immediately. Reclaiming Windows space is a two-stage operation: remove safe Linux data, then shut down WSL and compact the VHDX.
- `docker system df` reclaimable values are candidates, not permission to prune. Active images, stopped containers, build cache, and volumes have different risk profiles.

### Windows system files

- Report page-file allocation, current usage, peak usage, physical RAM, and whether Windows manages it automatically. Never call the whole page file “waste.”
- Report hibernation size and explain the feature tradeoff. Disabling hibernation also affects Fast Startup on many systems.

### Cloud storage and sparse files

- Distinguish logical length from allocated bytes whenever possible. OneDrive/Dropbox placeholders can look large while occupying little local disk.
- Do not recommend deleting a synchronized folder as a cache cleanup. Prefer “Free up space” or the provider’s online-only operation when appropriate.

### Developer tools

- Low-risk/rebuildable: npm/pnpm/yarn caches, pip/uv cache, Go build cache, crash dumps, logs, temporary installers, stale browser download fragments.
- Medium-risk/re-download required: Playwright browsers, package stores, old VS Code extension versions, Docker build cache, unused Docker images.
- Review first: VS Code `workspaceStorage`, browser Service Worker/IndexedDB, Codex/Claude session data, Claude VM bundles, Docker volumes, WSL project directories.
- High-risk/system-managed: page file, hibernation file, WSL VHDX, registry-managed application data, live database files.

## Output requirements

Use these sections in order:

1. `# Windows Developer Disk Usage Audit`
2. `## Executive summary`
3. `## Largest consumers`
4. `## Reclaim opportunities`
5. `## WSL analysis`
6. `## Developer tooling footprint`
7. `## Recommended action order`
8. `## Commands requiring approval`
9. `## Limitations and scan coverage`

Every size table should identify whether a value is logical, allocated, internally used, or an upper-bound estimate. Every cleanup suggestion should include a risk level and the consequence of cleanup.

## Bundled resources

- `scripts/Invoke-WindowsDevDiskAudit.ps1`: main read-only Windows scanner; produces Markdown and JSON.
- `scripts/Get-WslRuntimeAudit.sh`: optional read-only Linux/WSL runtime inspection used by the main scanner.
- `scripts/Test-WindowsDevDiskAudit.ps1`: deterministic smoke test using a temporary fake profile.
- `references/report-format.md`: required report contract and terminology.
- `examples/example-report.md`: sanitized example output.
- `evals/evals.json`: realistic skill-evaluation prompts and expected behavior.

## Cleanup handoff

When the user later asks to clean:

1. Reconfirm the exact candidates and estimated reclaim.
2. Separate low-risk caches from stateful data.
3. Show commands before executing any medium/high-risk action.
4. Measure free space before and after.
5. For WSL, verify workloads, prune only approved Docker objects/caches, shut down WSL, compact the exact VHDX, then verify distribution health and reclaimed Windows space.
