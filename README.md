# windows-dev-disk-audit

A reusable Codex/Claude skill for diagnosing Windows system-drive pressure on developer workstations that use WSL, Docker, VS Code, Codex, Claude Code, Node, Python, Rust, browsers, and cloud-sync folders.

一个面向 Windows 开发者的只读磁盘占用诊断 Skill，重点回答：

- C 盘究竟被什么占满？
- 大文件是 WSL `ext4.vhdx`、WSL swap，还是 Windows `pagefile.sys`？
- Docker、npm、pip、pnpm、uv、Playwright、VS Code、Codex、Claude Code 分别占多少？
- 哪些内容可安全重建，哪些需要人工确认？
- 为什么删掉 WSL 内文件后，C 盘空间没有立即回来？

## Design principles

- Read-only by default; the scanner never cleans, prunes, compacts, uninstalls, or changes system configuration.
- Separates logical, allocated, internally used, and estimated-reclaim sizes.
- Does not start stopped WSL distributions unless `-InspectWslRuntime` is explicitly supplied.
- Produces both Markdown for humans and JSON for automation.
- Uses a stable report format so audits can be compared over time.

## Repository layout

```text
SKILL.md
scripts/
  Invoke-WindowsDevDiskAudit.ps1
  Get-WslRuntimeAudit.sh
  Test-WindowsDevDiskAudit.ps1
references/
  report-format.md
examples/
  example-report.md
evals/
  evals.json
tests/
  Validate-Repository.ps1
```

## Run directly

```powershell
git clone https://github.com/hycarbon-b/windows-dev-disk-audit.git
cd windows-dev-disk-audit

# Fast, Windows-side, read-only scan. Stopped WSL distributions remain stopped.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsDevDiskAudit.ps1 `
  -Mode Fast `
  -OutputDirectory .\audit-output

# Optional: start WSL for df/swap/home-cache/Docker inspection.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsDevDiskAudit.ps1 `
  -Mode Fast `
  -InspectWslRuntime `
  -OutputDirectory .\audit-output-wsl
```

For a slower top-level drive scan, replace `-Mode Fast` with `-Mode Full`.

## Install as a skill

Clone or copy this repository into a skill directory recognized by your agent. Typical personal locations are:

```text
# Codex
%USERPROFILE%\.codex\skills\windows-dev-disk-audit\

# Claude Code / shared agent skills
%USERPROFILE%\.agents\skills\windows-dev-disk-audit\
```

Restart or reload the agent after installation. Example requests:

- “分析一下 Windows C 盘占用，重点检查 WSL、VS Code、Codex 和 Claude Code 缓存。”
- “Is WSL swap filling my C drive, or is it ext4.vhdx/Docker?”
- “Generate a read-only disk audit and rank safe cleanup candidates.”

## Validate

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Validate-Repository.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-WindowsDevDiskAudit.ps1
```

## Standard output

See [`examples/example-report.md`](examples/example-report.md). The mandatory contract is documented in [`references/report-format.md`](references/report-format.md).

## License

MIT
