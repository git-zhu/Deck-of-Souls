# 可选音效

阶段十五的 `GameAudio` 在文件存在时播放短音，缺失时静默（测试与无素材环境仍可通过）。

| 文件名 | ID | 建议用途 |
|--------|-----|----------|
| `ui_click.ogg` | `ui_click` | 地图节点选择、打出卡牌 |
| `victory.ogg` | `victory` | 通关胜利屏 |
| `defeat.ogg` | `defeat` | 死亡结算屏 |

将 OGG 放在本目录即可，无需改代码或 `project.godot` Autoload。
