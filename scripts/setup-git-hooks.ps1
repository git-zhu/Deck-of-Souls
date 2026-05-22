# One-time: enable repo post-commit hook (auto git push after commit).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
git config core.hooksPath .githooks
Write-Host "core.hooksPath set to .githooks — post-commit will run 'git push origin <branch>'."
Write-Host "Run this once per clone. To disable: git config --unset core.hooksPath"
