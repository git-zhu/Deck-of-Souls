# 音效

阶段十五的 `GameAudio` 在文件存在时播放短音，缺失时静默（测试与无素材环境仍可通过）。
P0 已随仓库内置三个自产合成 OGG（CC0，无版权素材），`audio_path_test` 校验存在性与可加载性。

| 文件名 | ID | 建议用途 | 内容 |
|--------|-----|----------|------|
| `ui_click.ogg` | `ui_click` | 地图节点选择、打出卡牌 | 1400Hz 短促点击（0.06s） |
| `victory.ogg` | `victory` | 通关胜利屏 | 上行 C 大调琶音（0.9s） |
| `defeat.ogg` | `defeat` | 死亡结算屏 | 低沉下行 A2→E2（1.2s） |

## 替换 / 新增

将你自己的 OGG 覆盖到本目录同名文件即可，无需改代码或 `project.godot` Autoload。
若需新增音效 ID：在 `scripts/ui/GameAudio.gd` 的 `PATHS` 字典中加一行，并在对应交互点调用 `GameAudio.play(parent, "id")`。
新增文件后需在 Godot 中重新导入（编辑器打开或 `godot4.6 --headless --path . --import`）。

## 测试

```bash
godot4.6 --headless --path . --script tools/audio_path_test.gd
```
