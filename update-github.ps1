param(
    [string]$Message = "Update VOR Hub $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
)

$ErrorActionPreference = "Stop"

$repoDirectory = $PSScriptRoot
$sourceDirectory = Split-Path $repoDirectory -Parent
$sourceFiles = @(
    "VOR_HUB.lua",
    "anime_expeditions.lua"
)
$git = "C:\Program Files\Git\cmd\git.exe"

if (-not (Test-Path -LiteralPath $git)) {
    $git = (Get-Command git -ErrorAction Stop).Source
}

foreach ($fileName in $sourceFiles) {
    $sourceFile = Join-Path $sourceDirectory $fileName
    if (-not (Test-Path -LiteralPath $sourceFile)) {
        throw "Hub source was not found: $sourceFile"
    }
    Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $repoDirectory $fileName) -Force
}

& $git -C $repoDirectory add -- $sourceFiles "update-github.ps1"
& $git -C $repoDirectory diff --cached --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "No hub changes to publish."
    exit 0
}

& $git -C $repoDirectory diff --cached --check
if ($LASTEXITCODE -ne 0) {
    throw "Git found formatting errors. Nothing was published."
}

& $git -C $repoDirectory commit -m $Message
if ($LASTEXITCODE -ne 0) {
    throw "Git commit failed."
}

& $git -C $repoDirectory push origin main
if ($LASTEXITCODE -ne 0) {
    throw "GitHub push failed."
}

Write-Host "Published: https://github.com/swatdiaz/VOR-HUB"
