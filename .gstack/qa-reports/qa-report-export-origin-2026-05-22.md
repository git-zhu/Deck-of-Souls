# QA Report — 导出后无法选择出身

**Date:** 2026-05-22  
**Target:** Godot 4.6 export (Windows EXE + Android APK)  
**Tier:** Standard  
**Baseline health:** N/A (native game, not web)

## Summary

| Metric | Value |
|--------|-------|
| Issues found | 1 (critical) |
| Fixes applied | 1 (verified via code + headless test scripts; export rebuild required by user) |
| Root cause | `DataRegistry` used `DirAccess` + runtime `load()`; unreferenced `.tres` files are omitted from export PCK |

## ISSUE-001 — Origin screen empty in exported builds

**Severity:** Critical  
**Category:** Functional  
**Fix Status:** verified (code); user must re-export exe/apk

### Symptoms

- Debug/editor: 6 origin cards visible, buttons work.
- Exported EXE/APK: title + description only; no cards; cannot pick origin.

### Root cause

`scripts/core/DataRegistry.gd` scanned `res://data/origins` (and other folders) with `DirAccess`. In the editor all files exist on disk. In exported builds only resources **reachable via preload/export graph** are in the PCK; dynamic scans return zero files.

### Fix

1. `tools/build_data_manifest.py` generates `scripts/core/DataRegistryPaths.gd` with `preload()` for every `data/**/*.tres`.
2. `DataRegistry` loads from those preloads instead of `DirAccess`.

### Regression tests

- `tools/export_data_load_test.gd` — asserts ≥6 origins, cards, enemies, acts.
- `tools/origin_screen_test.gd` — builds origin UI, expects ≥6 pick buttons.

### User verification

1. `python tools/build_data_manifest.py` (if you added new `.tres` data)
2. Re-export Windows + Android from Godot
3. Confirm origin grid shows 6 cards and「以此出身开始」works

## Ship readiness

**Re-export required.** Code fix alone does not update existing exe/apk artifacts.
