---
name: windows-dev-disk-audit
description: Diagnose Windows system-drive pressure on developer machines, especially where WSL, Docker, VS Code, Codex, Claude Code, browsers, and language-package caches may compete for space. Use when a user asks what is filling C:, whether WSL swap or ext4.vhdx is responsible, or which development caches are safe to review. Run the bundled read-only scanner and distinguish measured disk use from reclaim estimates; do not clean, prune, compact, or change Windows settings without explicit approval.
metadata:
  short-description: Diagnose Windows developer disk use
---

# Windows Developer Disk Audit

Use this skill to produce a reliable, read-only disk audit before recommending cleanup. The scanner accounts for common developer tooling and writes Markdown plus JSON so the report can be reviewed or reused.

## Workflow

1. Run the Windows-side scan first. It does not start stopped WSL distributions.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsDevDiskAudit.ps1 -Mode Fast -OutputDirectory .\audit-output
   ```

2. Read `windows-dev-disk-audit.md` for the user-facing result and `windows-dev-disk-audit.json` for raw values. Parent and child rows overlap; never add them together.
3. Use `-Mode Full` only when Fast mode does not explain the drive total. Full mode scans top-level folders and can take several minutes.
4. Ask permission before runtime WSL inspection. Only then use `-InspectWslRuntime`, which can start distributions to collect `df`, swap, home-cache, and Docker data.

## Interpretation and handoff

- Treat `ext4.vhdx`, WSL swap, Windows `pagefile.sys`, and `hiberfil.sys` as separate items. A VHDX is a filesystem container, not proof that swap is the cause.
- Label directory results as logical size unless allocated or internal use was directly measured. Cloud placeholders can make logical size exceed local allocation.
- Rebuildable language caches and temporary files are candidates; browser site data, editor workspace state, Codex/Claude data, Docker volumes, and WSL projects require review first.
- Docker reclaimability is an estimate. Cleaning Linux files will not return Windows space until the relevant VHDX is compacted after WSL shuts down.
- If the user approves cleanup, resolve exact targets, show the proposed commands, measure free space before/after, and treat VHDX, page-file, hibernation, and Docker-volume operations as separate approvals.

## Resources

- Run `scripts/Invoke-WindowsDevDiskAudit.ps1` for the Windows inventory.
- The script calls `scripts/Get-WslRuntimeAudit.sh` only for approved runtime WSL inspection.
- Read `references/report-format.md` when presenting, adapting, or validating the report format.
