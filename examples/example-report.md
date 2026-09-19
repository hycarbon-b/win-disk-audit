# Windows Developer Disk Usage Audit

Generated: 2026-01-15 14:30:00 +08:00
Scope: C:, Windows profile, WSL, VS Code, Codex, Claude Code
Mode: Fast

> This is a sanitized formatting example. Values and paths are illustrative.

## Executive summary

| Metric | Value |
|---|---:|
| Drive capacity | 512.00 GB |
| Used | 486.40 GB |
| Free | 25.60 GB |
| Used percent | 95.0% |
| High-confidence reclaim candidate | 58–76 GB |

The main pressure is a 180 GB WSL filesystem plus approximately 62 GB of reclaimable Docker image/build cache. WSL swap is configured at 4 GB and currently uses 0 B, so swap is not the cause. Windows developer caches provide another 14 GB of lower-risk candidates.

## Largest consumers

| Rank | Category | Path/item | Size | Size basis | Confidence |
|---:|---|---|---:|---|---|
| 1 | WSL virtual disk | `%LOCALAPPDATA%\Packages\...\ext4.vhdx` | 180.00 GB | allocated | measured |
| 2 | Windows virtual memory | `C:\pagefile.sys` | 32.00 GB | allocated | measured |
| 3 | Edge profile | `%LOCALAPPDATA%\Microsoft\Edge\User Data` | 21.40 GB | logical | measured |
| 4 | Claude desktop runtime | `%LOCALAPPDATA%\Claude-*\vm_bundles` | 10.10 GB | logical | measured |
| 5 | VS Code data | `%APPDATA%\Code` | 8.20 GB | logical | measured |

Do not add overlapping parent/child rows. For example, an AppData total already contains its named cache children.

## Reclaim opportunities

| Priority | Candidate | Estimated reclaim | Risk | Consequence |
|---:|---|---:|---|---|
| 1 | WSL Docker build cache | 34.00 GB | Medium | Future image builds take longer. |
| 2 | WSL unused images | 28.00 GB | Medium | Images must be pulled/built again; verify no stopped workload depends on them. |
| 3 | Windows npm/pnpm/uv caches | 7.80 GB | Low | Packages download again. |
| 4 | Playwright browsers | 3.60 GB | Medium | Browser binaries download again before tests run. |
| 5 | Downloads installers/old ISO | 12.00 GB | Review | Delete only files confirmed unnecessary. |

## WSL analysis

- `ext4.vhdx`: 180.00 GB allocated on Windows.
- Linux root filesystem: 168.00 GB internally used.
- Swap: 4.00 GB configured, 0 B used.
- Docker reports 62.00 GB reclaimable.
- After approved Linux/Docker cleanup, shut down WSL and compact the exact VHDX; internal deletion alone does not guarantee Windows free-space recovery.

## Developer tooling footprint

| Tool | Path | Size | Classification | Notes |
|---|---|---:|---|---|
| VS Code | `%APPDATA%\Code\User\workspaceStorage` | 3.80 GB | Review | May contain useful per-workspace extension state. |
| Codex | `%USERPROFILE%\.codex` | 2.40 GB | Review | Separate sessions/plugins from rebuildable cache. |
| Claude Code | `%USERPROFILE%\.claude` | 420 MB | Review | Preserve settings and project/session data. |
| npm | `%LOCALAPPDATA%\npm-cache` | 5.90 GB | Low | Rebuildable cache. |
| Go | `%LOCALAPPDATA%\go-build` | 900 MB | Low | Rebuildable compiler cache. |

## Recommended action order

1. Remove confirmed old ISO/installers and clear low-risk npm/uv/Go caches.
2. Review Docker’s reclaimable images and build cache against active/stopped projects.
3. Clear only approved WSL caches, then compact the VHDX after a WSL shutdown.
4. Review Edge Service Worker data and stale VS Code workspace storage through application-aware methods.
5. Consider page-file or hibernation changes only after ordinary cleanup and only if their feature tradeoffs are acceptable.

## Commands requiring approval

No cleanup command was executed. Before any cleanup, resolve exact paths, close affected applications, show the proposed commands, and obtain explicit approval. Docker prune, VHDX compaction, page-file changes, and hibernation changes require separate confirmation.

## Limitations and scan coverage

- Directory totals are logical unless marked allocated.
- Access-denied locations were skipped.
- Cloud placeholder files can overstate local allocation.
- Runtime WSL inspection starts a distribution; this example assumes permission was granted.
- Docker reclaimability is reported by Docker and is not a guarantee that every byte will return to C: before VHDX compaction.
