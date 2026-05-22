# 阶段六：记忆石 — 设计规格

**日期：** 2026-05-21  
**状态：** 阶段六已实现（2026-05-21）  
**前置：** 阶段五护符  
**实现计划：** `docs/superpowers/plans/2026-05-21-phase6-memory-stones.md`

## 目标

`RunState.memory_stones`（0–3）：每颗记忆石使战斗每回合开始时 **多抽 1 张牌**（在基础 5 张与护符加抽之上叠加）。

## 获得途径

- 赐福选项「聚焦记忆」
- 商人「记忆石」商品（65 卢恩）
- 已满 3 颗时不入池 / 不可购买

## 验收

- 抽牌数 = `5 + memory_stones + 护符 combat_extra_draw`
- Header 显示 `记忆石 n/3`
- `tools/memory_stone_test.gd` 通过

## 非目标

牌组上限、留牌、战灰替换
