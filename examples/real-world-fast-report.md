# Windows Developer Disk Usage Audit

Generated: 2026-09-19 17:42:58 +08:00
Scope: C:, profile `%USERPROFILE%`, WSL/VHDX, VS Code, Codex, Claude Code and common developer caches
Mode: Fast

> Sanitized real-world output. Measurements are retained; the Windows account name is replaced with `%USERPROFILE%` and package identifiers are shortened.

## Executive summary

| Metric | Value |
|---|---:|
| Drive capacity | 563.38 GB |
| Used | 555.13 GB |
| Free | 8.25 GB |
| Used percent | 98.5% |
| Low-risk cache upper bound | 15.01 GB |
| Physical RAM | 29.79 GB |

This is a read-only inventory. Reclaim estimates are candidates, not permission to delete. Overlapping rows are intentionally shown for diagnosis and must not be summed.

## Largest consumers

| Rank | Category | Path/item | Size | Size basis | Confidence |
|---:|---|---|---:|---|---|
| 1 | AppData child (overlapping) | `%LOCALAPPDATA%\Packages` | 218.24 GB | logical | measured |
| 2 | WSL virtual disk | `%LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_...\LocalState\ext4.vhdx` | 203.22 GB | allocated | measured |
| 3 | Windows system | `C:\pagefile.sys` | 61.02 GB | logical | measured |
| 4 | AppData child (overlapping) | `%LOCALAPPDATA%\Microsoft` | 28.98 GB | logical | measured |
| 5 | User data | `%USERPROFILE%\Downloads` | 19.07 GB | logical | measured |
| 6 | Windows system | `C:\hiberfil.sys` | 11.92 GB | logical | measured |
| 7 | AppData child (overlapping) | `%LOCALAPPDATA%\Claude-3p` | 10.59 GB | logical | measured |
| 8 | AppData child (overlapping) | `%APPDATA%\Code` | 8.50 GB | logical | measured |
| 9 | Application virtual disk | `%LOCALAPPDATA%\Packages\Claude_...\LocalCache\Roaming\Claude\vm_bundles\claudevm.bundle\rootfs.vhdx` | 8.40 GB | allocated | measured |
| 10 | AppData child (overlapping) | `%LOCALAPPDATA%\Programs` | 7.79 GB | logical | measured |
| 11 | npm cache | `%LOCALAPPDATA%\npm-cache` | 6.17 GB | logical | measured |
| 12 | VS Code extensions | `%USERPROFILE%\.vscode` | 4.23 GB | logical | measured |
| 13 | Playwright browsers | `%LOCALAPPDATA%\ms-playwright` | 3.17 GB | logical | measured |
| 14 | Codex home | `%USERPROFILE%\.codex` | 2.84 GB | logical | measured |
| 15 | uv cache | `%LOCALAPPDATA%\uv` | 2.12 GB | logical | measured |

## Reclaim opportunities

| Priority | Candidate | Estimated reclaim | Risk | Consequence |
|---:|---|---:|---|---|
| 1 | npm cache | 6.17 GB | Low | Rebuildable package cache. |
| 2 | Playwright browsers | 3.17 GB | Medium | Browser binaries must be downloaded again. |
| 3 | uv cache | 2.12 GB | Low | Rebuildable Python package cache. |
| 4 | Windows user temp | 1.50 GB | Low | Only stale, unlocked files are candidates. |
| 5 | Playwright MCP browsers | 1.39 GB | Medium | Browser binaries must be downloaded again. |
| 6 | pnpm store | 1.34 GB | Medium | Content-addressed store; cleanup causes re-downloads. |
| 7 | User cache | 1.29 GB | Low | Usually rebuildable, but inspect named children. |
| 8 | pnpm cache | 1.25 GB | Low | Rebuildable package cache. |
| 9 | Electron cache | 1.17 GB | Low | Usually rebuildable download cache. |
| 10 | Go build cache | 1.04 GB | Low | Rebuildable compiler cache. |

## WSL analysis

- WSL `ext4.vhdx`: logical 203.22 GB; allocated 203.22 GB.
- Runtime inspection was not requested, so stopped distributions were not started. WSL swap usage, Linux `df`, user caches, and Docker reclaimability remain unmeasured.
- A large `ext4.vhdx` is a filesystem container, not evidence that swap is responsible. Internal deletion and VHDX compaction are separate operations.

## Developer tooling footprint

| Tool/item | Path | Size | Classification | Notes |
|---|---|---:|---|---|
| Packages | `%LOCALAPPDATA%\Packages` | 218.24 GB | Review | Overlaps parent/application rows; inspect before cleanup. |
| Microsoft | `%LOCALAPPDATA%\Microsoft` | 28.98 GB | Review | Overlaps parent/application rows; inspect before cleanup. |
| Claude-3p | `%LOCALAPPDATA%\Claude-3p` | 10.59 GB | Review | Overlaps parent/application rows; inspect before cleanup. |
| Code | `%APPDATA%\Code` | 8.50 GB | Review | Overlaps parent/application rows; inspect before cleanup. |
| npm cache | `%LOCALAPPDATA%\npm-cache` | 6.17 GB | Low | Rebuildable package cache. |
| VS Code extensions | `%USERPROFILE%\.vscode` | 4.23 GB | Medium | Old extension versions may be removable; current extensions are application state. |
| Playwright browsers | `%LOCALAPPDATA%\ms-playwright` | 3.17 GB | Medium | Browser binaries must be downloaded again. |
| Codex home | `%USERPROFILE%\.codex` | 2.84 GB | Review | Contains skills, plugins, sessions, and caches; inspect children before cleanup. |
| uv cache | `%LOCALAPPDATA%\uv` | 2.12 GB | Low | Rebuildable Python package cache. |
| Windows user temp | `%LOCALAPPDATA%\Temp` | 1.50 GB | Low | Only stale, unlocked files are candidates. |

## Recommended action order

1. Confirm low-risk, rebuildable caches and stale downloads; measure free space after each category.
2. Review browser site storage, editor workspace state, package stores, Playwright browsers, and unused tool versions before removal.
3. Inspect WSL runtime and Docker only with approval. Delete approved internal data before compacting the exact VHDX.
4. Treat page-file and hibernation changes as system configuration; consider them only after ordinary cleanup.

## Commands requiring approval

No cleanup, prune, compaction, uninstall, page-file, or hibernation command was executed. Generate exact commands only after the user approves specific targets.

## Limitations and scan coverage

- Directory totals are logical sizes unless explicitly labeled allocated.
- Rows from parent and child directories overlap and must not be added together.
- Access-denied files are skipped.
- Cloud placeholders can make logical size larger than local allocated size.
- Stopped WSL distributions were not started; internal usage and Docker reclaimability were not measured.
