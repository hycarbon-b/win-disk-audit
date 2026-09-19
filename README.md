# Windows Developer Disk Audit

An Agent Skill for read-only diagnosis of Windows system-drive pressure on developer machines using WSL, Docker, VS Code, Codex, Claude Code, browsers, and language-package caches.

The installable Skill is [`skills/windows-dev-disk-audit`](skills/windows-dev-disk-audit). It intentionally contains only agent instructions, UI metadata, executable helpers, and a report-format reference. Repository documentation, examples, tests, and evaluations stay outside that installable folder.

## Install

Copy or clone the skill folder—not this repository root—into your agent's skill directory:

```powershell
git clone https://github.com/hycarbon-b/windows-dev-disk-audit.git
Copy-Item .\windows-dev-disk-audit\skills\windows-dev-disk-audit "$env:USERPROFILE\.codex\skills\windows-dev-disk-audit" -Recurse
```

Restart Codex after installation. The skill is then eligible whenever a user asks why Windows C: is full, whether WSL swap/VHDX is responsible, or which developer caches are safe to review.

## Use directly

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\windows-dev-disk-audit\scripts\Invoke-WindowsDevDiskAudit.ps1 -Mode Fast -OutputDirectory .\audit-output
```

The scanner is read-only. It does not start stopped WSL distributions unless `-InspectWslRuntime` is explicitly supplied, and it never performs cleanup.

## Development

- [Report format example](examples/example-report.md)
- [Evaluation prompts](evals/evals.json)
- [Validation scripts](tests)

## License

MIT
