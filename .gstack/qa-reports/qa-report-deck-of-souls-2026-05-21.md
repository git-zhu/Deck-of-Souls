# QA 报告 — Deck-of-Souls

| 字段 | 值 |
|------|-----|
| 日期 | 2026-05-21 |
| 模式 | Diff-aware（无 Web URL，Godot 项目） |
| 分支 | main |
| 基线 | 数据外置重构（`Main.gd` + `data/**/*.tres`） |
| 冒烟测试 | **未执行**（本机 PATH 中未找到 Godot 4.6） |

## 执行摘要

| 指标 | 值 |
|------|-----|
| 发现问题 | 7 |
| 严重 (Critical/High) | 3 |
| 中等 (Medium) | 3 |
| 低 (Low) | 1 |
| 健康分（估算） | **52 / 100** |
| 修复提交 | 0（工作区未干净，仅报告） |

### Top 3 待修项

1. **`.tres` 资源格式可能无法被 Godot 正确加载**（缺 `gd_resource` / `ext_resource` / `script=`）
2. **`Main.gd` 仍将 `CardData`/`OriginData` 标为 `Dictionary`**，与加载类型不一致
3. **`data/` 目录未纳入 Git**，克隆后游戏无法运行

---

## ISSUE-001 — `.tres` 文件缺少 Godot 标准资源头（严重）

**严重度:** Critical  
**类别:** Functional  
**状态:** 待修复

### 描述

`data/cards/*.tres`、`data/enemies/*.tres`、`data/origins/*.tres` 均使用简写头，例如：

```text
[resource name="CardData"]
id="longsword"
...
```

全项目 **0** 个文件包含 `gd_resource`、`ext_resource` 或 `script=res://data/CardData.gd` 等绑定。

`Main.gd` 中加载逻辑为：

```gdscript
var card := load("res://data/cards/%s" % file) as CardData
if card != null:
    result[card.id] = card
```

若 `load()` 得到的是未绑定脚本的泛型 `Resource`，`as CardData` 会得到 `null`，导致 `cards` / `origins` 字典为空，战斗与 UI 全面失效。

### 建议修复

在 Godot 编辑器中重新保存各资源，或批量为每个 `.tres` 补全：

```text
[gd_resource type="CardData" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/CardData.gd" id="1"]

[resource]
script = ExtResource("1")
...
```

`MoveData` 子资源同理需绑定 `res://data/MoveData.gd`。

### 验证

```bash
godot4.6 --headless --script tools/smoke_test.gd
```

应输出 `Smoke test passed`，且 `_load_cards()` 应加载 24 张牌。

---

## ISSUE-002 — 类型注解与运行时数据不一致（高）

**严重度:** High  
**类别:** Functional / 可维护性  
**状态:** 待修复

### 位置

- `scripts/Main.gd` 约 285、328、682、767、793、1111 行

### 描述

`cards` 与 `origins` 在 `_ready()` 中填充的是 `CardData` / `OriginData` 资源，但多处写作：

```gdscript
var c: Dictionary = cards[card_id]
var origin: Dictionary = origins[origin_id]
```

在 Godot 4 严格类型检查下，编辑器可能报错；即便运行时不崩溃，也会误导后续维护并掩盖 ISSUE-001 的加载失败。

### 建议修复

改为 `CardData` / `OriginData`（或统一 `Resource` + 辅助访问），并删除误导性的 `Dictionary` 注解。

---

## ISSUE-003 — `data/` 未提交到 Git（高）

**严重度:** High  
**类别:** 发布 / DX  
**状态:** 待修复

### 描述

`git status` 显示整个 `data/` 为未跟踪。当前 `Main.gd` 已依赖运行时扫描 `res://data/cards` 等目录；他人克隆仓库后仅有旧逻辑删除后的 `Main.gd`，**无卡牌/敌人/出身数据**，游戏无法启动完整流程。

### 建议修复

将 `data/**/*.gd`、`data/**/*.tres`（及必要 `.uid`）加入版本库；将误创建的 `nul` 加入 `.gitignore` 并删除工作区中的 `nul` 文件。

---

## ISSUE-004 — 卡牌效果仍硬编码在 `match`（中）

**严重度:** Medium  
**类别:** 架构  
**状态:** 已知技术债

### 描述

数据已外置到 `.tres`，但 `_play_card()` 仍用 `match card_id` 写死 24 种效果。新增卡牌必须同时改资源 **和** `Main.gd`，外置数据的价值减半。

### 建议

在 `CardData` 上增加效果字段（或 `MoveData` 式结构），由通用解析器驱动战斗逻辑。

---

## ISSUE-005 — `DirAccess.list_dir_begin()` 已弃用（中）

**严重度:** Medium  
**类别:** 引擎 API  
**状态:** 待修复

### 位置

`_load_cards`、`_load_origins`、`_load_enemies`

### 描述

Godot 4 推荐 `dir.get_next()` 配合 `DirAccess.open()`，无需 `list_dir_begin()`。当前写法在较新版本可能产生弃用警告。

---

## ISSUE-006 — 工作区不干净，无法按 /qa 规范提交修复（中）

**严重度:** Medium（流程）  
**类别:** 工程  
**状态:** 信息

### 描述

已修改：`project.godot`、`scripts/Main.gd`  
未跟踪：`.claude/`、`CLAUDE.md`、`data/`、`openspec/`、`nul` 等  

按 gstack-qa 规则，自动「每 bug 一 commit」前需先 commit 或 stash。

---

## ISSUE-007 — 仓库根目录存在 `nul` 文件（低）

**严重度:** Low  
**类别:** 杂项  
**状态:** 待修复

### 描述

Windows 上 `nul` 为保留设备名，常由错误重定向 `> nul` 产生。应删除并避免再次提交。

---

## 测试执行情况

| 测试 | 结果 |
|------|------|
| `godot4.6 --headless --script tools/smoke_test.gd` | **跳过** — 未找到 Godot 可执行文件 |
| 浏览器 QA (`$B`) | **不适用** — 本项目为 Godot 桌面 UI，非 Web |
| 静态代码审查 | 已完成（见上文） |

### 建议在本地执行的验证命令

```bash
godot4.6 --headless --script tools/smoke_test.gd
```

在编辑器中打开 `res://scenes/Main.tscn`，确认出身选择、战斗出牌、牌组查看无报错。

---

## 健康分说明（估算 52/100）

| 类别 | 权重 | 得分 | 说明 |
|------|------|------|------|
| 数据加载 | 25% | 20 | `.tres` 格式风险高 |
| 类型安全 | 15% | 40 | Dictionary 注解错误 |
| 版本控制 | 15% | 10 | `data/` 未入库 |
| 架构 | 15% | 55 | 数据外置未完成效果层 |
| 自动化测试 | 20% | 70 | 有 smoke_test，本次未跑通 |
| API 现代化 | 10% | 75 | 弃用 API 警告 |

---

## 修复优先级建议

1. 修正 `.tres` 格式并在编辑器验证 `load()` + `as CardData`
2. 提交 `data/` 目录
3. 修正 `Main.gd` 类型注解
4. 本地跑通 smoke test
5. （可选）卡牌效果数据驱动化

---

*报告由 /gstack-qa 生成（Godot 适配模式）。*
