Set-StrictMode -Version 2.0

function Get-AuditDirectoryLogicalBytes {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }

    $nullDestination = Join-Path $env:TEMP '__windows_dev_disk_audit_null__'
    $output = & robocopy.exe $Path $nullDestination /L /S /BYTES /XJ /R:0 /W:0 /NFL /NDL /NP 2>$null
    $bytesLine = $output | Select-String '^\s*Bytes\s*:' | Select-Object -Last 1
    if ($bytesLine -and $bytesLine.Line -match '^\s*Bytes\s*:\s*([0-9]+)') {
        return [long]$matches[1]
    }

    [long]$sum = 0
    Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $sum += $_.Length }
    return $sum
}

function New-AuditRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Module,
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Path,
        [Nullable[long]]$LogicalBytes,
        [string]$Classification = 'Review',
        [string]$Notes = ''
    )
    [pscustomobject]@{
        schema_version = '1.0'
        module = $Module
        category = $Category
        path = $Path
        logical_bytes = $LogicalBytes
        classification = $Classification
        notes = $Notes
    }
}

function Write-AuditRecords {
    param([object[]]$Records, [switch]$AsObject)
    if ($AsObject) { Write-Output $Records; return }
    $Records | ConvertTo-Json -Depth 5
}

Export-ModuleMember -Function Get-AuditDirectoryLogicalBytes, New-AuditRecord, Write-AuditRecords
