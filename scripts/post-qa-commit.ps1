# After /gstack-qa (or manual QA): commit verified fixes + report, then push.
# Usage: .\scripts\post-qa-commit.ps1 [-Message "custom message"] [-SkipPush]
param(
    [string]$Message = "",
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
# git prints CRLF warnings to stderr; do not treat as failure
$prevEap = $ErrorActionPreference
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$date = Get-Date -Format "yyyy-MM-dd"
if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "fix(qa): headless QA pass $date — compile, acts, tests"
}

$paths = @(
    "scripts/",
    "data/",
    "tools/",
    ".gstack/qa-reports/",
    "CLAUDE.md",
    ".gitignore"
)
if (Test-Path ".godot/global_script_class_cache.cfg") {
    $paths += ".godot/global_script_class_cache.cfg"
}

$ErrorActionPreference = "Continue"
git add @paths 2>&1 | Out-Null
$ErrorActionPreference = $prevEap
$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host "post-qa-commit: nothing to commit (working tree clean for QA paths)."
    exit 0
}

git commit -m $Message
Write-Host "Committed: $Message"

$hooksPath = git config core.hooksPath 2>$null
if ($SkipPush) {
    Write-Host "SkipPush set — not pushing."
    exit 0
}
if ($hooksPath -eq ".githooks") {
    Write-Host "post-commit hook will push to origin (core.hooksPath=.githooks)."
} else {
    $branch = git branch --show-current
    git push origin $branch
    Write-Host "Pushed to origin/$branch"
}
