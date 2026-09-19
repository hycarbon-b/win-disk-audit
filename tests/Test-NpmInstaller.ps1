[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path $env:TEMP ('windows-dev-disk-audit-npm-test-' + [guid]::NewGuid().ToString('N'))
$target = Join-Path $tempRoot 'skills'
$cli = Join-Path (Split-Path -Parent $PSScriptRoot) 'bin\windows-dev-disk-audit.js'

try {
    & node $cli install --target $target
    if ($LASTEXITCODE -ne 0) { throw 'Initial npm CLI installation failed.' }
    $installed = Join-Path $target 'windows-dev-disk-audit'
    foreach ($relative in @('SKILL.md', 'agents\openai.yaml', 'scripts\Invoke-WindowsDevDiskAudit.ps1', 'scripts\modules\Get-WslUsage.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $installed $relative))) {
            throw ('Installer omitted required file: ' + $relative)
        }
    }

    & node $cli install --target $target --replace
    if ($LASTEXITCODE -ne 0) { throw 'Replacement npm CLI installation failed.' }
    if (-not (Get-ChildItem -LiteralPath $target -Directory | Where-Object Name -like 'windows-dev-disk-audit.backup-*')) {
        throw 'Replacement installation did not preserve a backup.'
    }
    Write-Output 'PASS: npm installer copies the standard Skill and preserves a replace backup.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
