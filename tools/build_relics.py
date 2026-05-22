"""Generate data/relics/*.tres (UTF-8)."""
from pathlib import Path

RELICS = [
    ("serpentbone_talisman", "蛇骨护符", "每场战斗开始获得 1 点力量。", "combat_strength", 1),
    ("crimson_amulet", "深红护符", "获得时最大生命 +10。", "on_acquire_max_hp", 10),
    ("cerulean_medallion", "蔚蓝勋章", "每场战斗开始额外 1 点集中。", "combat_extra_ember", 1),
    ("ancestral_spirit", "祖灵骨灰瓶", "每场战斗开始多抽 1 张牌。", "combat_extra_draw", 1),
    ("greatshield_talisman", "大盾护符", "每场战斗开始获得 4 点护甲。", "combat_start_block", 4),
    ("erdtree_favor", "黄金树恩惠", "获得时最大生命 +12。", "on_acquire_max_hp", 12),
    ("green_turtle_talisman", "绿龟护符", "每场战斗开始获得 3 点护甲。", "combat_start_block", 3),
    ("gold_scarab", "金色粪金龟", "每场战斗胜利额外获得 5 卢恩。", "combat_souls_bonus", 5),
]


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "data" / "relics"
    out.mkdir(parents=True, exist_ok=True)
    for rid, name, body, hook, value in RELICS:
        content = f"""[gd_resource type="Resource" script_class="RelicData" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/RelicData.gd" id="1"]

[resource]
script = ExtResource("1")
id = "{rid}"
name = "{name}"
body = "{body}"
hook = "{hook}"
value = {value}
"""
        path = out / f"{rid}.tres"
        path.write_text(content, encoding="utf-8")
        print(path)


if __name__ == "__main__":
    main()
