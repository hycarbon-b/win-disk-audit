[CmdletBinding()]
param(
    [ValidateSet('All', 'Edge', 'Chrome')]
    [string]$Browser = 'All',
    [string]$ProfileRoot = $env:USERPROFILE,
    [switch]$AsObject
)

Import-Module (Join-Path $PSScriptRoot 'AuditCommon.psm1') -Force
$local = Join-Path ([IO.Path]::GetFullPath($ProfileRoot)) 'AppData\Local'
$targets = @()
if ($Browser -in @('All', 'Edge')) {
    $targets += @{ Category='Edge profile'; Path=(Join-Path $local 'Microsoft\Edge\User Data'); Notes='Browser profile; review Service Worker, IndexedDB, and Cache in browser settings before removal.' }
}
if ($Browser -in @('All', 'Chrome')) {
    $targets += @{ Category='Chrome profile'; Path=(Join-Path $local 'Google\Chrome\User Data'); Notes='Browser profile; review Service Worker, IndexedDB, and Cache in browser settings before removal.' }
}

$records = foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target.Path -PathType Container)) { continue }
    $bytes = Get-AuditDirectoryLogicalBytes -Path $target.Path
    New-AuditRecord -Module 'browser-storage' -Category $target.Category -Path $target.Path `
        -LogicalBytes $bytes -Classification 'Review' -Notes $target.Notes
}
Write-AuditRecords -Records $records -AsObject:$AsObject
