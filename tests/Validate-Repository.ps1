[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$required = @(
    'README.md',
    'LICENSE',
    'skills\windows-dev-disk-audit\SKILL.md',
    'skills\windows-dev-disk-audit\agents\openai.yaml',
    'skills\windows-dev-disk-audit\scripts\Invoke-WindowsDevDiskAudit.ps1',
    'skills\windows-dev-disk-audit\scripts\Get-WslRuntimeAudit.sh',
    'skills\windows-dev-disk-audit\references\report-format.md',
    'examples\example-report.md',
    'evals\evals.json'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) { throw ('Missing required file: ' + $relative) }
}

$skill = Get-Content -LiteralPath (Join-Path $root 'skills\windows-dev-disk-audit\SKILL.md') -Raw -Encoding UTF8
if ($skill -notmatch '(?s)^---\s+name:\s+windows-dev-disk-audit\s+description:') {
    throw 'SKILL.md frontmatter is missing or invalid.'
}
if (($skill -split "`n").Count -gt 500) { throw 'SKILL.md exceeds 500 lines.' }

$uiMetadata = Get-Content -LiteralPath (Join-Path $root 'skills\windows-dev-disk-audit\agents\openai.yaml') -Raw -Encoding UTF8
foreach ($field in @('display_name:', 'short_description:', 'default_prompt:')) {
    if (-not $uiMetadata.Contains($field)) { throw ('agents/openai.yaml missing field: ' + $field) }
}

$evals = Get-Content -LiteralPath (Join-Path $root 'evals\evals.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($evals.skill_name -ne 'windows-dev-disk-audit') { throw 'evals.json skill_name mismatch.' }
if (@($evals.evals).Count -lt 3) { throw 'At least three eval cases are required.' }

$example = Get-Content -LiteralPath (Join-Path $root 'examples\example-report.md') -Raw -Encoding UTF8
$headings = @(
    '## Executive summary',
    '## Largest consumers',
    '## Reclaim opportunities',
    '## WSL analysis',
    '## Developer tooling footprint',
    '## Recommended action order',
    '## Commands requiring approval',
    '## Limitations and scan coverage'
)
foreach ($heading in $headings) {
    if (-not $example.Contains($heading)) { throw ('Example report missing heading: ' + $heading) }
}

Write-Output 'PASS: repository structure, skill metadata, evals, and example format are valid.'
