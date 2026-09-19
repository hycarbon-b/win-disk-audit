[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path $env:TEMP ('win-disk-audit-test-' + [guid]::NewGuid().ToString('N'))
$profile = Join-Path $tempRoot 'profile'
$output = Join-Path $tempRoot 'output'

try {
    $paths = @(
        (Join-Path $profile 'Downloads'),
        (Join-Path $profile '.codex'),
        (Join-Path $profile '.claude'),
        (Join-Path $profile 'AppData\Local\npm-cache'),
        (Join-Path $profile 'AppData\Local\Temp'),
        (Join-Path $profile 'AppData\Roaming\Code\User\workspaceStorage')
    )
    foreach ($path in $paths) { New-Item -ItemType Directory -Path $path -Force | Out-Null }

    [IO.File]::WriteAllBytes((Join-Path $profile 'Downloads\sample.iso'), (New-Object byte[] (2MB)))
    [IO.File]::WriteAllBytes((Join-Path $profile 'AppData\Local\npm-cache\cache.bin'), (New-Object byte[] (1MB)))
    [IO.File]::WriteAllBytes((Join-Path $profile '.codex\state.bin'), (New-Object byte[] (256KB)))

    $scanner = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\win-disk-audit\scripts\Invoke-WinDiskAudit.ps1'
    & $scanner -Mode Fast -ProfileRoot $profile -OutputDirectory $output -Top 10

    $jsonPath = Join-Path $output 'win-disk-audit.json'
    $markdownPath = Join-Path $output 'win-disk-audit.md'
    if (-not (Test-Path -LiteralPath $jsonPath)) { throw 'JSON report was not created.' }
    if (-not (Test-Path -LiteralPath $markdownPath)) { throw 'Markdown report was not created.' }

    $json = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $markdown = Get-Content -LiteralPath $markdownPath -Raw -Encoding UTF8
    if (-not $json.Metadata.ReadOnly) { throw 'Report did not preserve the read-only marker.' }
    if (-not ($json.Consumers | Where-Object Name -eq 'npm cache')) { throw 'npm cache was not detected.' }
    foreach ($heading in @(
        '## Executive summary',
        '## Largest consumers',
        '## Reclaim opportunities',
        '## WSL analysis',
        '## Developer tooling footprint',
        '## Recommended action order',
        '## Commands requiring approval',
        '## Limitations and scan coverage'
    )) {
        if (-not $markdown.Contains($heading)) { throw ('Missing report heading: ' + $heading) }
    }

    Write-Output 'PASS: scanner created valid JSON and the standard Markdown report.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
