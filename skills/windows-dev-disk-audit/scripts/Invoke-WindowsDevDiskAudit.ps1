[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter = 'C',

    [ValidateSet('Fast', 'Full')]
    [string]$Mode = 'Fast',

    [string]$OutputDirectory = (Join-Path (Get-Location) 'audit-output'),

    [string]$ProfileRoot = $env:USERPROFILE,

    [switch]$InspectWslRuntime,

    [ValidateRange(5, 100)]
    [int]$Top = 25
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Format-ByteSize {
    param([Nullable[long]]$Bytes)
    if ($null -eq $Bytes) { return 'n/a' }
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0} B' -f $Bytes)
}

function Escape-MarkdownCell {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value -replace '\|', '\|') -replace "`r?`n", ' '
}

function Convert-WindowsPathToWsl {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path -match '^([A-Za-z]):\\(.*)$') {
        return ('/mnt/{0}/{1}' -f $matches[1].ToLowerInvariant(), ($matches[2] -replace '\\', '/'))
    }
    throw ('Cannot convert this path to a standard WSL mount path: ' + $Path)
}

function Get-DirectoryLogicalBytes {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }
    $nullDestination = Join-Path $env:TEMP '__windows_dev_disk_audit_null__'
    $output = & robocopy.exe $Path $nullDestination /L /S /BYTES /XJ /R:0 /W:0 /NFL /NDL /NP 2>$null
    $bytesLine = $output | Select-String '^\s*Bytes\s*:' | Select-Object -Last 1
    if ($bytesLine -and $bytesLine.Line -match '^\s*Bytes\s*:\s*([0-9]+)') {
        return [long]$matches[1]
    }

    # Locale or robocopy-output fallback. This can be slower but keeps the
    # scanner useful on Windows installations with localized footer labels.
    [long]$sum = 0
    Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object { $sum += $_.Length }
    return $sum
}

function Initialize-AllocatedSizeHelper {
    if ('WindowsDevDiskAudit.NativeSize' -as [type]) { return }
    $source = @'
using System;
using System.Runtime.InteropServices;
namespace WindowsDevDiskAudit {
    public static class NativeSize {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern uint GetCompressedFileSizeW(string fileName, out uint high);
        [DllImport("kernel32.dll")]
        static extern void SetLastError(uint errorCode);
        public static ulong GetAllocatedBytes(string path) {
            SetLastError(0);
            uint high;
            uint low = GetCompressedFileSizeW(path, out high);
            int error = Marshal.GetLastWin32Error();
            if (low == 0xffffffff && error != 0) return 0;
            return ((ulong)high << 32) | low;
        }
    }
}
'@
    Add-Type -TypeDefinition $source
}

function Get-AllocatedFileBytes {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        Initialize-AllocatedSizeHelper
        return [long][WindowsDevDiskAudit.NativeSize]::GetAllocatedBytes($Path)
    }
    catch {
        return $null
    }
}

function New-Consumer {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Path,
        [Nullable[long]]$LogicalBytes,
        [Nullable[long]]$AllocatedBytes,
        [string]$SizeBasis,
        [string]$Confidence,
        [string]$Classification,
        [string]$Notes
    )
    return [pscustomobject]@{
        Category       = $Category
        Name           = $Name
        Path           = $Path
        LogicalBytes   = $LogicalBytes
        AllocatedBytes = $AllocatedBytes
        SizeBasis      = $SizeBasis
        Confidence     = $Confidence
        Classification = $Classification
        Notes          = $Notes
    }
}

function Add-DirectoryConsumer {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Path,
        [string]$Classification = 'Review',
        [string]$Notes = ''
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }
    $bytes = Get-DirectoryLogicalBytes -Path $Path
    return New-Consumer -Category $Category -Name $Name -Path $Path -LogicalBytes $bytes `
        -AllocatedBytes $null -SizeBasis 'logical' -Confidence 'measured' `
        -Classification $Classification -Notes $Notes
}

function Get-SafeChildDirectories {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
}

$DriveLetter = $DriveLetter.ToUpperInvariant()
$driveRoot = '{0}:\' -f $DriveLetter
$ProfileRoot = [IO.Path]::GetFullPath($ProfileRoot)
$localAppData = Join-Path $ProfileRoot 'AppData\Local'
$roamingAppData = Join-Path $ProfileRoot 'AppData\Roaming'
$generatedAt = Get-Date

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

$driveInfo = New-Object IO.DriveInfo ($DriveLetter + ':')
$volume = [pscustomobject]@{
    Drive       = $DriveLetter + ':'
    Capacity    = [long]$driveInfo.TotalSize
    Free        = [long]$driveInfo.AvailableFreeSpace
    Used        = [long]($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace)
    UsedPercent = [math]::Round((($driveInfo.TotalSize - $driveInfo.AvailableFreeSpace) / $driveInfo.TotalSize) * 100, 1)
}

$computer = $null
$pageFiles = @()
try { $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { }
try {
    $pageFiles = @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{
            Name         = $_.Name
            Allocated    = [long]$_.AllocatedBaseSize * 1MB
            CurrentUsage = [long]$_.CurrentUsage * 1MB
            PeakUsage    = [long]$_.PeakUsage * 1MB
        }
    })
}
catch { }

$systemFiles = @()
foreach ($systemName in @('pagefile.sys', 'hiberfil.sys', 'swapfile.sys')) {
    $item = Get-ChildItem -LiteralPath $driveRoot -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $systemName } | Select-Object -First 1
    if ($item) {
        $systemFiles += [pscustomobject]@{
            Name = $systemName
            Path = $item.FullName
            LogicalBytes = [long]$item.Length
        }
    }
}

$consumers = @()

foreach ($systemFile in $systemFiles) {
    $notes = 'System-managed file; do not delete directly.'
    if ($systemFile.Name -eq 'pagefile.sys') {
        $notes = 'Windows virtual memory; evaluate allocation, current use, peak use, RAM, and crash-dump requirements.'
    }
    elseif ($systemFile.Name -eq 'hiberfil.sys') {
        $notes = 'Supports hibernation and commonly Fast Startup; changing it alters Windows features.'
    }
    $consumers += New-Consumer -Category 'Windows system' -Name $systemFile.Name -Path $systemFile.Path `
        -LogicalBytes $systemFile.LogicalBytes -AllocatedBytes $null -SizeBasis 'logical' `
        -Confidence 'measured' -Classification 'High' -Notes $notes
}

$knownProfilePaths = @(
    @{ Category='User data'; Name='Downloads'; Relative='Downloads'; Class='Review'; Notes='Installers, archives, ISO files, and partial downloads are common.' },
    @{ Category='Developer tooling'; Name='VS Code extensions'; Relative='.vscode'; Class='Medium'; Notes='Old extension versions may be removable; current extensions are application state.' },
    @{ Category='Developer tooling'; Name='Codex home'; Relative='.codex'; Class='Review'; Notes='Contains skills, plugins, sessions, and caches; inspect children before cleanup.' },
    @{ Category='Developer tooling'; Name='Claude Code home'; Relative='.claude'; Class='Review'; Notes='Contains settings, sessions, projects, and caches.' },
    @{ Category='Developer cache'; Name='User cache'; Relative='.cache'; Class='Low'; Notes='Usually rebuildable, but inspect named children.' },
    @{ Category='Developer tooling'; Name='Bun'; Relative='.bun'; Class='Medium'; Notes='May include package cache and installed binaries.' },
    @{ Category='Developer cache'; Name='pnpm user data'; Relative='.pnpm'; Class='Medium'; Notes='Package store may require downloads after cleanup.' },
    @{ Category='Developer tooling'; Name='Rust toolchains'; Relative='.rustup'; Class='Review'; Notes='Installed toolchains are not cache.' }
)

foreach ($entry in $knownProfilePaths) {
    $path = Join-Path $ProfileRoot $entry.Relative
    $row = Add-DirectoryConsumer -Category $entry.Category -Name $entry.Name -Path $path `
        -Classification $entry.Class -Notes $entry.Notes
    if ($row) { $consumers += $row }
}

Get-SafeChildDirectories -Path $ProfileRoot | Where-Object { $_.Name -like 'OneDrive*' } | ForEach-Object {
    $row = Add-DirectoryConsumer -Category 'Cloud sync' -Name $_.Name -Path $_.FullName `
        -Classification 'Review' -Notes 'Logical size may include online-only placeholders; use provider Free up space instead of deleting.'
    if ($row) { $consumers += $row }
}

$knownCaches = @(
    @{ Name='npm cache'; Path=(Join-Path $localAppData 'npm-cache'); Class='Low'; Notes='Rebuildable package cache.' },
    @{ Name='pnpm cache'; Path=(Join-Path $localAppData 'pnpm-cache'); Class='Low'; Notes='Rebuildable package cache.' },
    @{ Name='pnpm store'; Path=(Join-Path $localAppData 'pnpm'); Class='Medium'; Notes='Content-addressed store; cleanup causes re-downloads.' },
    @{ Name='uv cache'; Path=(Join-Path $localAppData 'uv'); Class='Low'; Notes='Rebuildable Python package cache.' },
    @{ Name='Go build cache'; Path=(Join-Path $localAppData 'go-build'); Class='Low'; Notes='Rebuildable compiler cache.' },
    @{ Name='Playwright browsers'; Path=(Join-Path $localAppData 'ms-playwright'); Class='Medium'; Notes='Browser binaries must be downloaded again.' },
    @{ Name='Playwright MCP browsers'; Path=(Join-Path $localAppData 'ms-playwright-mcp'); Class='Medium'; Notes='Browser binaries must be downloaded again.' },
    @{ Name='Windows user temp'; Path=(Join-Path $localAppData 'Temp'); Class='Low'; Notes='Only stale, unlocked files are candidates.' },
    @{ Name='Electron cache'; Path=(Join-Path $localAppData 'electron'); Class='Low'; Notes='Usually rebuildable download cache.' },
    @{ Name='Electron Builder cache'; Path=(Join-Path $localAppData 'electron-builder'); Class='Low'; Notes='Usually rebuildable build cache.' }
)

foreach ($entry in $knownCaches) {
    $row = Add-DirectoryConsumer -Category 'Developer cache' -Name $entry.Name -Path $entry.Path `
        -Classification $entry.Class -Notes $entry.Notes
    if ($row) { $consumers += $row }
}

# AppData children expose application-specific hot spots while keeping the scan
# bounded. They overlap with named cache rows and must not be summed together.
foreach ($appBase in @($localAppData, $roamingAppData)) {
    foreach ($child in (Get-SafeChildDirectories -Path $appBase)) {
        $row = Add-DirectoryConsumer -Category 'AppData child (overlapping)' -Name $child.Name `
            -Path $child.FullName -Classification 'Review' `
            -Notes 'Overlaps parent/application rows; inspect before cleanup.'
        if ($row -and $row.LogicalBytes -ge 100MB) { $consumers += $row }
    }
}

$vhdxFiles = @()
$vhdSearchRoots = @(
    (Join-Path $localAppData 'Packages'),
    (Join-Path $localAppData 'Docker'),
    (Join-Path $localAppData 'Temp')
)
foreach ($searchRoot in $vhdSearchRoots) {
    if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) { continue }
    $found = Get-ChildItem -LiteralPath $searchRoot -Filter '*.vhdx' -File -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($file in $found) {
        $allocated = Get-AllocatedFileBytes -Path $file.FullName
        $kind = 'Application'
        if ($file.FullName -match '(?i)Canonical|Ubuntu|\\wsl\\|WSLDistribution') { $kind = 'WSL' }
        elseif ($file.FullName -match '(?i)\\Docker\\|docker_data') { $kind = 'Docker' }
        $vhdxFiles += [pscustomobject]@{
            Path           = $file.FullName
            Kind           = $kind
            LogicalBytes   = [long]$file.Length
            AllocatedBytes = $allocated
            Modified       = $file.LastWriteTime
        }
        $consumers += New-Consumer -Category ($kind + ' virtual disk') -Name $file.Name -Path $file.FullName `
            -LogicalBytes ([long]$file.Length) -AllocatedBytes $allocated -SizeBasis 'allocated' `
            -Confidence 'measured' -Classification 'High' `
            -Notes ($kind + ' container file; inspect internal filesystem before cleanup. Never delete directly.')
    }
}

if ($Mode -eq 'Full') {
    foreach ($child in (Get-SafeChildDirectories -Path $driveRoot)) {
        $row = Add-DirectoryConsumer -Category 'Drive top-level (overlapping)' -Name $child.Name `
            -Path $child.FullName -Classification 'Review' `
            -Notes 'Full-mode top-level total; overlaps more specific rows.'
        if ($row) { $consumers += $row }
    }
}

$wslRuntime = @()
if ($InspectWslRuntime -and (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    $wslAuditScript = Join-Path $PSScriptRoot 'Get-WslRuntimeAudit.sh'
    $rawDistros = & wsl.exe --list --quiet 2>$null
    foreach ($rawName in @($rawDistros)) {
        $distro = (($rawName -replace "`0", '').Trim())
        if ([string]::IsNullOrWhiteSpace($distro)) { continue }
        try {
            $linuxScript = Convert-WindowsPathToWsl -Path $wslAuditScript
            $runtimeText = (& wsl.exe -d $distro -- bash $linuxScript 2>&1) -join "`n"
            $wslRuntime += [pscustomobject]@{
                Distribution = $distro
                StartedByAudit = $true
                Output = $runtimeText
            }
        }
        catch {
            $wslRuntime += [pscustomobject]@{
                Distribution = $distro
                StartedByAudit = $true
                Output = 'Runtime inspection failed: ' + $_.Exception.Message
            }
        }
    }
}

$sortedConsumers = @($consumers | Sort-Object @{Expression={
    if ($null -ne $_.AllocatedBytes -and $_.AllocatedBytes -gt 0) { $_.AllocatedBytes } else { $_.LogicalBytes }
}} -Descending)

$reclaimCandidates = @($sortedConsumers | Where-Object {
    $_.Category -eq 'Developer cache' -and $_.LogicalBytes -gt 0
} | ForEach-Object {
    [pscustomobject]@{
        Candidate = $_.Name
        Path = $_.Path
        EstimatedBytes = $_.LogicalBytes
        Risk = $_.Classification
        Consequence = $_.Notes
        Confidence = 'upper bound'
    }
})
$lowRiskUpperBound = [long](($reclaimCandidates | Where-Object Risk -eq 'Low' |
    Measure-Object -Property EstimatedBytes -Sum).Sum)

$result = [ordered]@{
    Metadata = [ordered]@{
        GeneratedAt = $generatedAt.ToString('o')
        ComputerName = $env:COMPUTERNAME
        Mode = $Mode
        Drive = $volume.Drive
        ProfileRoot = $ProfileRoot
        InspectWslRuntime = [bool]$InspectWslRuntime
        ReadOnly = $true
    }
    Volume = $volume
    Computer = [ordered]@{
        PhysicalMemoryBytes = if ($computer) { [long]$computer.TotalPhysicalMemory } else { $null }
        AutomaticManagedPagefile = if ($computer) { [bool]$computer.AutomaticManagedPagefile } else { $null }
    }
    PageFiles = $pageFiles
    SystemFiles = $systemFiles
    VhdxFiles = $vhdxFiles
    Consumers = $sortedConsumers
    ReclaimCandidates = $reclaimCandidates
    LowRiskCacheUpperBound = $lowRiskUpperBound
    WslRuntime = $wslRuntime
    Limitations = @(
        'Directory totals are logical sizes unless explicitly labeled allocated.',
        'Rows from parent and child directories overlap and must not be added together.',
        'Access-denied files are skipped.',
        'Cloud placeholders can make logical size larger than local allocated size.',
        $(if ($InspectWslRuntime) { 'WSL distributions were started for runtime inspection.' } else { 'Stopped WSL distributions were not started; internal usage and Docker reclaimability were not measured.' })
    )
}

$jsonPath = Join-Path $OutputDirectory 'windows-dev-disk-audit.json'
$markdownPath = Join-Path $OutputDirectory 'windows-dev-disk-audit.md'
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$md = New-Object Text.StringBuilder
[void]$md.AppendLine('# Windows Developer Disk Usage Audit')
[void]$md.AppendLine()
[void]$md.AppendLine(('Generated: {0}' -f $generatedAt.ToString('yyyy-MM-dd HH:mm:ss zzz')))
[void]$md.AppendLine(('Scope: {0}, profile `{1}`, WSL/VHDX, VS Code, Codex, Claude Code and common developer caches' -f $volume.Drive, $ProfileRoot))
[void]$md.AppendLine(('Mode: {0}' -f $Mode))
[void]$md.AppendLine()
[void]$md.AppendLine('## Executive summary')
[void]$md.AppendLine()
[void]$md.AppendLine('| Metric | Value |')
[void]$md.AppendLine('|---|---:|')
[void]$md.AppendLine(('| Drive capacity | {0} |' -f (Format-ByteSize $volume.Capacity)))
[void]$md.AppendLine(('| Used | {0} |' -f (Format-ByteSize $volume.Used)))
[void]$md.AppendLine(('| Free | {0} |' -f (Format-ByteSize $volume.Free)))
[void]$md.AppendLine(('| Used percent | {0}% |' -f $volume.UsedPercent))
[void]$md.AppendLine(('| Low-risk cache upper bound | {0} |' -f (Format-ByteSize $lowRiskUpperBound)))
if ($computer) {
    [void]$md.AppendLine(('| Physical RAM | {0} |' -f (Format-ByteSize ([long]$computer.TotalPhysicalMemory))))
}
[void]$md.AppendLine()
[void]$md.AppendLine('This is a read-only inventory. Reclaim estimates are candidates, not permission to delete. Overlapping rows are intentionally shown for diagnosis and must not be summed.')
[void]$md.AppendLine()
[void]$md.AppendLine('## Largest consumers')
[void]$md.AppendLine()
[void]$md.AppendLine('| Rank | Category | Path/item | Size | Size basis | Confidence |')
[void]$md.AppendLine('|---:|---|---|---:|---|---|')
$rank = 0
foreach ($row in ($sortedConsumers | Select-Object -First $Top)) {
    $rank++
    $displayBytes = if ($null -ne $row.AllocatedBytes -and $row.AllocatedBytes -gt 0) { $row.AllocatedBytes } else { $row.LogicalBytes }
    [void]$md.AppendLine(('| {0} | {1} | `{2}` | {3} | {4} | {5} |' -f $rank,
        (Escape-MarkdownCell $row.Category), (Escape-MarkdownCell $row.Path),
        (Format-ByteSize $displayBytes), $row.SizeBasis, $row.Confidence))
}
[void]$md.AppendLine()
[void]$md.AppendLine('## Reclaim opportunities')
[void]$md.AppendLine()
[void]$md.AppendLine('| Priority | Candidate | Estimated reclaim | Risk | Consequence |')
[void]$md.AppendLine('|---:|---|---:|---|---|')
$priority = 0
foreach ($candidate in ($reclaimCandidates | Sort-Object EstimatedBytes -Descending)) {
    $priority++
    [void]$md.AppendLine(('| {0} | {1} | {2} | {3} | {4} |' -f $priority,
        (Escape-MarkdownCell $candidate.Candidate), (Format-ByteSize $candidate.EstimatedBytes),
        $candidate.Risk, (Escape-MarkdownCell $candidate.Consequence)))
}
if ($priority -eq 0) { [void]$md.AppendLine('| — | No known cache candidates measured | — | — | Run Full mode or inspect application-specific data |') }
[void]$md.AppendLine()
[void]$md.AppendLine('## WSL analysis')
[void]$md.AppendLine()
if ($vhdxFiles.Count -eq 0) {
    [void]$md.AppendLine('- No VHDX files were found in the standard WSL/Docker locations scanned.')
}
else {
    $wslRelatedVhdx = @($vhdxFiles | Where-Object { $_.Kind -eq 'WSL' -or $_.Kind -eq 'Docker' })
    if ($wslRelatedVhdx.Count -eq 0) {
        [void]$md.AppendLine('- No WSL or Docker VHDX was identified. Application-owned VHDX files, if any, are listed under Largest consumers.')
    }
    foreach ($vhd in $wslRelatedVhdx) {
        [void]$md.AppendLine(('- {0} `{1}`: logical {2}; allocated {3}.' -f $vhd.Kind, $vhd.Path,
            (Format-ByteSize $vhd.LogicalBytes), (Format-ByteSize $vhd.AllocatedBytes)))
    }
}
if ($InspectWslRuntime) {
    [void]$md.AppendLine('- Runtime inspection was requested. Raw per-distribution output is included below.')
    foreach ($runtime in $wslRuntime) {
        [void]$md.AppendLine()
        [void]$md.AppendLine(('### {0}' -f $runtime.Distribution))
        [void]$md.AppendLine()
        [void]$md.AppendLine('```text')
        [void]$md.AppendLine($runtime.Output)
        [void]$md.AppendLine('```')
    }
}
else {
    [void]$md.AppendLine('- Runtime inspection was not requested, so stopped distributions were not started. WSL swap usage, Linux `df`, user caches, and Docker reclaimability remain unmeasured.')
}
[void]$md.AppendLine('- A large `ext4.vhdx` is a filesystem container, not evidence that swap is responsible. Internal deletion and VHDX compaction are separate operations.')
[void]$md.AppendLine()
[void]$md.AppendLine('## Developer tooling footprint')
[void]$md.AppendLine()
[void]$md.AppendLine('| Tool/item | Path | Size | Classification | Notes |')
[void]$md.AppendLine('|---|---|---:|---|---|')
foreach ($row in ($sortedConsumers | Where-Object { $_.Category -match 'Developer|AppData' } | Select-Object -First $Top)) {
    $displayBytes = if ($null -ne $row.AllocatedBytes -and $row.AllocatedBytes -gt 0) { $row.AllocatedBytes } else { $row.LogicalBytes }
    [void]$md.AppendLine(('| {0} | `{1}` | {2} | {3} | {4} |' -f
        (Escape-MarkdownCell $row.Name), (Escape-MarkdownCell $row.Path),
        (Format-ByteSize $displayBytes), $row.Classification, (Escape-MarkdownCell $row.Notes)))
}
[void]$md.AppendLine()
[void]$md.AppendLine('## Recommended action order')
[void]$md.AppendLine()
[void]$md.AppendLine('1. Confirm low-risk, rebuildable caches and stale downloads; measure free space after each category.')
[void]$md.AppendLine('2. Review browser site storage, editor workspace state, package stores, Playwright browsers, and unused tool versions before removal.')
[void]$md.AppendLine('3. Inspect WSL runtime and Docker only with approval. Delete approved internal data before compacting the exact VHDX.')
[void]$md.AppendLine('4. Treat page-file and hibernation changes as system configuration; consider them only after ordinary cleanup.')
[void]$md.AppendLine()
[void]$md.AppendLine('## Commands requiring approval')
[void]$md.AppendLine()
[void]$md.AppendLine('No cleanup, prune, compaction, uninstall, page-file, or hibernation command was executed. Generate exact commands only after the user approves specific targets.')
[void]$md.AppendLine()
[void]$md.AppendLine('## Limitations and scan coverage')
[void]$md.AppendLine()
foreach ($limitation in $result.Limitations) { [void]$md.AppendLine(('- {0}' -f $limitation)) }

$md.ToString() | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Output ('Markdown report: {0}' -f $markdownPath)
Write-Output ('JSON report:     {0}' -f $jsonPath)
Write-Output ('Free space:      {0} ({1}% used)' -f (Format-ByteSize $volume.Free), $volume.UsedPercent)
