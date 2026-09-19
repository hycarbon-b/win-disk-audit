[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path,
    [switch]$AsObject
)

Import-Module (Join-Path $PSScriptRoot 'AuditCommon.psm1') -Force
$records = foreach ($item in $Path) {
    $resolved = Resolve-Path -LiteralPath $item -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) { continue }
    if (Test-Path -LiteralPath $resolved.Path -PathType Container) {
        $bytes = Get-AuditDirectoryLogicalBytes -Path $resolved.Path
        New-AuditRecord -Module 'directory-usage' -Category 'Directory' -Path $resolved.Path `
            -LogicalBytes $bytes -Classification 'Review' `
            -Notes 'Logical size; use this module for evidence-led follow-up paths not covered by the baseline scan.'
    }
}
Write-AuditRecords -Records $records -AsObject:$AsObject
