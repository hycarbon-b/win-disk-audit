[CmdletBinding()]
param(
    [string]$ProfileRoot = $env:USERPROFILE,
    [switch]$Runtime,
    [switch]$AsObject
)

Import-Module (Join-Path $PSScriptRoot 'AuditCommon.psm1') -Force

function Convert-WindowsPathToWsl {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path -match '^([A-Za-z]):\\(.*)$') {
        return ('/mnt/{0}/{1}' -f $matches[1].ToLowerInvariant(), ($matches[2] -replace '\\', '/'))
    }
    throw ('Cannot convert this path to a standard WSL mount path: ' + $Path)
}

$local = Join-Path ([IO.Path]::GetFullPath($ProfileRoot)) 'AppData\Local'
$records = @()
$packageRoot = Join-Path $local 'Packages'
if (Test-Path -LiteralPath $packageRoot -PathType Container) {
    Get-ChildItem -LiteralPath $packageRoot -Filter '*.vhdx' -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '(?i)Canonical|Ubuntu|WSL' } |
        ForEach-Object {
            $records += New-AuditRecord -Module 'wsl-usage' -Category 'WSL VHDX' -Path $_.FullName `
                -LogicalBytes ([long]$_.Length) -Classification 'High' `
                -Notes 'Filesystem container; inspect internal data before cleanup and compact only after approved WSL cleanup.'
        }
}

if ($Runtime) {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'wsl.exe is not available.' }
    $runtimeScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'Get-WslRuntimeAudit.sh'
    $rawDistros = & wsl.exe --list --quiet 2>$null
    foreach ($rawName in @($rawDistros)) {
        $distro = (($rawName -replace "`0", '').Trim())
        if ([string]::IsNullOrWhiteSpace($distro)) { continue }
        $linuxScript = Convert-WindowsPathToWsl -Path $runtimeScript
        $runtimeOutput = (& wsl.exe -d $distro -- bash $linuxScript 2>&1) -join "`n"
        $records += [pscustomobject]@{
            schema_version = '1.0'
            module = 'wsl-usage'
            category = 'WSL runtime'
            path = $distro
            logical_bytes = $null
            classification = 'Review'
            notes = 'Runtime inspection starts the distribution. Raw output follows.'
            runtime_output = $runtimeOutput
        }
    }
}

Write-AuditRecords -Records $records -AsObject:$AsObject
