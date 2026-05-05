param(
    [string]$Source = 'E:\SelfProject\doro-novel\src-tauri\target\debug\resources\character',
    [string]$Target = '.\l2d',
    [switch]$DryRun,
    [switch]$SyncSpineCharacterJson,
    [switch]$CommitAndPush,
    [string]$CommitMessage = 'chore: sync missing l2d characters'
)

$ErrorActionPreference = 'Stop'

function Resolve-ExistingDirectory {
    param(
        [string]$Path,
        [string]$Name
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "$Name directory does not exist: $Path"
    }
    return $resolved.Path
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    return $Path.Substring($Root.Length + 1)
}

$sourceRoot = Resolve-ExistingDirectory -Path $Source -Name 'Source'
$targetRoot = Resolve-ExistingDirectory -Path $Target -Name 'Target'
$repoRoot = (Resolve-Path -LiteralPath '.').Path

Write-Host "Source: $sourceRoot" -ForegroundColor Cyan
Write-Host "Target: $targetRoot" -ForegroundColor Cyan

$targetDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -LiteralPath $targetRoot -Directory | ForEach-Object {
    [void]$targetDirs.Add($_.Name)
}

$missingDirs = Get-ChildItem -LiteralPath $sourceRoot -Directory |
    Where-Object { -not $targetDirs.Contains($_.Name) } |
    Sort-Object Name

$targetFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -LiteralPath $targetRoot -Recurse -File | ForEach-Object {
    [void]$targetFiles.Add((Get-RelativePath -Root $targetRoot -Path $_.FullName))
}

$missingFiles = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File |
    Where-Object {
        $relativePath = Get-RelativePath -Root $sourceRoot -Path $_.FullName
        $relativePath -ne 'spine-character.json' -and -not $targetFiles.Contains($relativePath)
    } |
    Sort-Object FullName

$sourceManifest = Join-Path $sourceRoot 'spine-character.json'
$targetManifest = Join-Path $targetRoot 'spine-character.json'
$manifestStatus = 'not found in source'
$manifestNeedsCopy = $false

if (Test-Path -LiteralPath $sourceManifest) {
    if (-not (Test-Path -LiteralPath $targetManifest)) {
        $manifestStatus = 'missing'
        $manifestNeedsCopy = $SyncSpineCharacterJson
    }
    else {
        $sourceManifestHash = (Get-FileHash -LiteralPath $sourceManifest -Algorithm SHA256).Hash
        $targetManifestHash = (Get-FileHash -LiteralPath $targetManifest -Algorithm SHA256).Hash
        if ($sourceManifestHash -ne $targetManifestHash) {
            $manifestStatus = 'different'
            $manifestNeedsCopy = $SyncSpineCharacterJson
        }
        else {
            $manifestStatus = 'up to date'
        }
    }
}

Write-Host "Missing character directories: $($missingDirs.Count)" -ForegroundColor Yellow
if ($missingDirs.Count -gt 0) {
    $missingDirs | ForEach-Object { Write-Host "  $($_.Name)" }
}

Write-Host "Missing files: $($missingFiles.Count)" -ForegroundColor Yellow
if ($missingFiles.Count -gt 0) {
    $missingFiles | ForEach-Object {
        Write-Host "  $(Get-RelativePath -Root $sourceRoot -Path $_.FullName)"
    }
}
Write-Host "spine-character.json: $manifestStatus" -ForegroundColor Yellow
if ($manifestNeedsCopy) {
    Write-Host "spine-character.json will be copied because -SyncSpineCharacterJson was set." -ForegroundColor Yellow
}
elseif ($manifestStatus -eq 'missing' -or $manifestStatus -eq 'different') {
    Write-Host "spine-character.json was not copied. Use -SyncSpineCharacterJson to overwrite it from source." -ForegroundColor Yellow
}

if ($DryRun) {
    Write-Host "Dry run only. No files were copied." -ForegroundColor Cyan
    exit 0
}

foreach ($dir in $missingDirs) {
    $destination = Join-Path $targetRoot $dir.Name
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath $dir.FullName -Destination $destination -Recurse
    }
}

foreach ($file in $missingFiles) {
    $relativePath = Get-RelativePath -Root $sourceRoot -Path $file.FullName
    $destination = Join-Path $targetRoot $relativePath
    $destinationDir = Split-Path -Parent $destination

    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir | Out-Null
    }
    if (-not (Test-Path -LiteralPath $destination)) {
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
}

if ($manifestNeedsCopy) {
    Copy-Item -LiteralPath $sourceManifest -Destination $targetManifest -Force
}

if (($missingDirs.Count + $missingFiles.Count) -eq 0 -and -not $manifestNeedsCopy) {
    Write-Host "No missing l2d character resources found." -ForegroundColor Green
    exit 0
}

Write-Host "Copied missing l2d character resources." -ForegroundColor Green

if ($CommitAndPush) {
    Push-Location $repoRoot
    try {
        git add -- l2d
        if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

        git commit -m $CommitMessage
        if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }

        git push origin main
        if ($LASTEXITCODE -ne 0) { throw 'git push failed' }
    }
    finally {
        Pop-Location
    }
}
