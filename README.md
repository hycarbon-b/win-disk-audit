# Win Disk Audit

An Agent Skill for read-only diagnosis of Windows system-drive pressure on developer machines using WSL, Docker, VS Code, Codex, Claude Code, browsers, and language-package caches.

The installable Skill is [`skills/win-disk-audit`](skills/win-disk-audit). It intentionally contains only agent instructions, UI metadata, executable helpers, and a report-format reference. Repository documentation, examples, tests, and evaluations stay outside that installable folder.

## Install from GitHub with npm

Install the Skill into Codex with one command:

```powershell
npx --yes github:hycarbon-b/win-disk-audit install --agent codex
```

The installer copies only `skills/win-disk-audit` into `%USERPROFILE%\.codex\skills\win-disk-audit`; it does not scan disks, start WSL, or delete data. Restart Codex or start a new task after installation.

Other supported targets:

```powershell
# Claude Code
npx --yes github:hycarbon-b/win-disk-audit install --agent claude

# Shared agent-skill location
npx --yes github:hycarbon-b/win-disk-audit install --agent agents

# An explicit skills parent directory
npx --yes github:hycarbon-b/win-disk-audit install --target D:\agent-skills
```

If an installed copy exists, use `--replace`; the installer moves the previous Skill to a timestamped backup in the same directory.

## Collection modules

The installed Skill begins with a read-only baseline scan, then an agent selects additional collectors only when their results are relevant:

| Collector | Use when |
|---|---|
| `Get-DeveloperToolUsage.ps1` | VS Code, Codex, Claude, or package caches need breakdown. |
| `Get-BrowserStorage.ps1` | Edge or Chrome profile data is a material consumer. |
| `Get-WslUsage.ps1` | WSL VHDX needs analysis; add `-Runtime` only after permission. |
| `Get-DirectoryUsage.ps1` | An exact unexplained path needs a follow-up measurement. |

Modules output consistent JSON records, allowing the agent to collect additional evidence without altering the core scanner or fabricating a report schema.

## Real-world example output

This is a sanitized Fast-mode report produced on a real Windows developer machine. The measurements are retained; the Windows account name is replaced with `%USERPROFILE%`.

<details>
<summary>Expand the report preview</summary>

### Executive summary

| Metric | Value |
|---|---:|
| Drive capacity | 563.38 GB |
| Used | 555.13 GB |
| Free | 8.25 GB |
| Used percent | 98.5% |
| Low-risk cache upper bound | 15.01 GB |
| Physical RAM | 29.79 GB |

This is a read-only inventory. Reclaim estimates are candidates, not permission to delete. Overlapping rows are intentionally shown for diagnosis and must not be summed.

### Largest consumers

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

### Reclaim opportunities

| Priority | Candidate | Estimated reclaim | Risk | Consequence |
|---:|---|---:|---|---|
| 1 | npm cache | 6.17 GB | Low | Rebuildable package cache. |
| 2 | Playwright browsers | 3.17 GB | Medium | Browser binaries must be downloaded again. |
| 3 | uv cache | 2.12 GB | Low | Rebuildable Python package cache. |
| 4 | Windows user temp | 1.50 GB | Low | Only stale, unlocked files are candidates. |
| 5 | Playwright MCP browsers | 1.39 GB | Medium | Browser binaries must be downloaded again. |
| 6 | pnpm store | 1.34 GB | Medium | Cleanup causes re-downloads. |

### WSL analysis

- `ext4.vhdx`: 203.22 GB allocated on Windows.
- Runtime inspection was not requested, so stopped distributions were not started.
- A large `ext4.vhdx` is a filesystem container, not evidence that swap is responsible.
- Internal deletion and VHDX compaction are separate operations.

### Recommended action order

1. Confirm rebuildable caches and stale downloads; measure free space after each category.
2. Review browser, editor workspace, package-store, and Playwright state before removal.
3. Inspect WSL runtime and Docker only with approval; clean approved internal data before compacting the exact VHDX.
4. Treat page-file and hibernation changes as system configuration, after ordinary cleanup.

</details>

The complete sanitized report is available at [examples/real-world-fast-report.md](examples/real-world-fast-report.md).

## Development

- [Report format example](examples/example-report.md)
- [Evaluation prompts](evals/evals.json)
- [Validation scripts](tests)

## License

MIT
