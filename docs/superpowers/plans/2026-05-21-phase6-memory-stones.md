# 阶段六：记忆石 — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-05-21-phase6-memory-stones-design.md`

1. `RunState.memory_stones` + `MAX_MEMORY_STONES = 3` + `player_hand_draw()` helper
2. `CombatController` use helper for draw count
3. `GraceService` / `MerchantService` effect `memory_stone`
4. `build_grace_options.py` + `build_merchant_offers.py` + regenerate .tres
5. `Main` header + docs + `memory_stone_test.gd` + **git commit**
