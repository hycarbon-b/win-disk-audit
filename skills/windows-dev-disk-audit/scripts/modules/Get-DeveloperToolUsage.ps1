[CmdletBinding()]
param(
    [string]$ProfileRoot = $env:USERPROFILE,
    [switch]$AsObject
)

Import-Module (Join-Path $PSScriptRoot 'AuditCommon.psm1') -Force
$profilePath = [IO.Path]::GetFullPath($ProfileRoot)
$local = Join-Path $profilePath 'AppData\Local'
$roaming = Join-Path $profilePath 'AppData\Roaming'
$targets = @(
    @{ Category='VS Code'; Path=(Join-Path $profilePath '.vscode'); Classification='Review'; Notes='Extensions and versions; current extensions are application state.' },
    @{ Category='VS Code'; Path=(Join-Path $roaming 'Code'); Classification='Review'; Notes='Workspace storage, logs, extensions, and cached data.' },
    @{ Category='Codex'; Path=(Join-Path $profilePath '.codex'); Classification='Review'; Notes='May contain skills, plugins, sessions, and caches.' },
    @{ Category='Codex'; Path=(Join-Path $local 'Packages\OpenAI.Codex_2p2nqsd0c76g0'); Classification='Review'; Notes='Store-app state; inspect before changing.' },
    @{ Category='Claude Code'; Path=(Join-Path $profilePath '.claude'); Classification='Review'; Notes='Settings, project/session data, and caches.' },
    @{ Category='Claude'; Path=(Join-Path $local 'Claude-3p'); Classification='Review'; Notes='Desktop runtime bundles and application state.' },
    @{ Category='Claude'; Path=(Join-Path $local 'Packages\Claude_pzs8sxrjxfjjc'); Classification='Review'; Notes='Store-app state and virtual-machine bundles.' },
    @{ Category='Node cache'; Path=(Join-Path $local 'npm-cache'); Classification='Low'; Notes='Rebuildable npm cache.' },
    @{ Category='Python cache'; Path=(Join-Path $local 'uv'); Classification='Low'; Notes='Rebuildable uv cache.' },
    @{ Category='Browser test cache'; Path=(Join-Path $local 'ms-playwright'); Classification='Medium'; Notes='Browser binaries download again after cleanup.' },
    @{ Category='Build cache'; Path=(Join-Path $local 'go-build'); Classification='Low'; Notes='Rebuildable Go compiler cache.' }
)

$records = foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target.Path -PathType Container)) { continue }
    $bytes = Get-AuditDirectoryLogicalBytes -Path $target.Path
    New-AuditRecord -Module 'developer-tool-usage' -Category $target.Category -Path $target.Path `
        -LogicalBytes $bytes -Classification $target.Classification -Notes $target.Notes
}
Write-AuditRecords -Records $records -AsObject:$AsObject
