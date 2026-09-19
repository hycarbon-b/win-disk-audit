# Windows Developer Disk Audit

An Agent Skill for read-only diagnosis of Windows system-drive pressure on developer machines using WSL, Docker, VS Code, Codex, Claude Code, browsers, and language-package caches.

The installable Skill is [`skills/windows-dev-disk-audit`](skills/windows-dev-disk-audit). It intentionally contains only agent instructions, UI metadata, executable helpers, and a report-format reference. Repository documentation, examples, tests, and evaluations stay outside that installable folder.

## Install from GitHub with npm

Install the Skill into Codex with one command:

```powershell
npx --yes github:hycarbon-b/windows-dev-disk-audit install --agent codex
```

The installer copies only `skills/windows-dev-disk-audit` into `%USERPROFILE%\.codex\skills\windows-dev-disk-audit`; it does not scan disks, start WSL, or delete data. Restart Codex or start a new task after installation.

Other supported targets:

```powershell
# Claude Code
npx --yes github:hycarbon-b/windows-dev-disk-audit install --agent claude

# Shared agent-skill location
npx --yes github:hycarbon-b/windows-dev-disk-audit install --agent agents

# An explicit skills parent directory
npx --yes github:hycarbon-b/windows-dev-disk-audit install --target D:\agent-skills
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

## Development

- [Report format example](examples/example-report.md)
- [Evaluation prompts](evals/evals.json)
- [Validation scripts](tests)

## License

MIT
