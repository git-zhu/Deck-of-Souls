#!/usr/bin/env sh
# One-time: enable repo post-commit hook (auto git push after commit).
set -e
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
echo "core.hooksPath set to .githooks — post-commit will run 'git push origin <branch>'."
echo "Run this once per clone. To disable: git config --unset core.hooksPath"
