"""Generate data/acts/*.tres with MapNodeData grace and merchant nodes."""
from pathlib import Path

ACTS = [
    {
        "id": "limgrave",
        "title": "宁姆格福路标",
        "flavor": "沿赐福指引穿过风暴山丘，接近候王礼拜堂的阴影。",
        "combat": ["葛瑞克士兵", "野狼", "凯丹佣兵", "挖石矿工", "学院辉石法师"],
        "elite": ["法姆亚兹拉的兽人", "亚人首领", "挖石山妖"],
        "grace": [
            ("赐福点", "回复生命，补充圣杯瓶，或用卢恩触碰命定之死。"),
            ("艾雷教堂", "短暂停歇。锻造台旁的金光提醒你整理牌组。"),
        ],
        "merchant": [
            ("商人咖列", "流浪商人坐在熄灭篝火旁，货箱上贴着褪色者也能看懂的价签。"),
        ],
        "boss_name": "恶兆妖鬼玛尔基特",
        "boss_title": "通城隧道",
        "boss_body": "恶兆妖鬼玛尔基特守在史东薇尔城前。穿过这道雾门，宁姆格福的开局才算结束。",
        "final": False,
    },
    {
        "id": "stormveil",
        "title": "史东薇尔城塞",
        "flavor": "城墙内回荡着接肢的金属声，黄金树的枝桠在雾上摇晃。",
        "combat": ["葛瑞克骑士", "腐败眷属", "挖石山妖", "凯丹佣兵"],
        "elite": ["熔炉骑士", "守墓斗士", "法姆亚兹拉的兽人"],
        "grace": [
            ("城墙赐福", "在狭窄走廊里喘息，整理被撕破的战意。"),
            ("格密尔英雄墓", "墓碑旁的金光让你想起尚未完成的誓言。"),
        ],
        "merchant": [
            ("城墙下的咖列", "咖列把货箱藏在垛口后，只卖给还能喘气的褪色者。"),
        ],
        "boss_name": "熔炉骑士",
        "boss_title": "风暴山丘封牢",
        "boss_body": "熔炉骑士的古老武艺仍在回响。击败他，城塞的大门才会松动。",
        "final": False,
    },
    {
        "id": "liurnia",
        "title": "湖之利耶尼亚",
        "flavor": "金色倒影铺在湖面，学院与教堂的钟声在雾中重叠。",
        "combat": ["学院辉石法师", "腐败眷属", "葛瑞克骑士", "凯丹佣兵"],
        "elite": ["熔炉骑士", "守墓斗士", "挖石山妖"],
        "grace": [
            ("学院门前赐福", "辉石光芒退入石缝，你得以审视自己的牌路。"),
            ("教堂侧廊", "溺水教堂的寒气被金光挡在门外。"),
        ],
        "merchant": [],
        "boss_name": "接肢贵族",
        "boss_title": "贵族厅堂",
        "boss_body": "接肢贵族在湖底厅堂等待。胜利意味着这趟褪色旅程暂时落幕。",
        "final": True,
    },
]


def write_act(path: Path, act: dict) -> None:
    node_blocks = []
    node_refs = []
    idx = 0

    for title, body in act.get("grace", []):
        node_blocks.append(
            f'''[sub_resource type="Resource" id="Node_{idx}"]
script = ExtResource("2")
kind = "grace"
title = "{title}"
body = "{body}"
'''
        )
        node_refs.append(f'SubResource("Node_{idx}")')
        idx += 1

    for title, body in act.get("merchant", []):
        node_blocks.append(
            f'''[sub_resource type="Resource" id="Node_{idx}"]
script = ExtResource("2")
kind = "merchant"
title = "{title}"
body = "{body}"
'''
        )
        node_refs.append(f'SubResource("Node_{idx}")')
        idx += 1

    combat_str = ", ".join(f'"{n}"' for n in act["combat"])
    elite_str = ", ".join(f'"{n}"' for n in act["elite"])
    fixed_str = ", ".join(node_refs)
    load_steps = idx + 3

    content = f'''[gd_resource type="Resource" script_class="ActData" load_steps={load_steps} format=3]

[ext_resource type="Script" path="res://data/ActData.gd" id="1"]
[ext_resource type="Script" path="res://data/MapNodeData.gd" id="2"]

{"".join(node_blocks)}
[resource]
script = ExtResource("1")
id = "{act["id"]}"
title = "{act["title"]}"
subtitle_template = "第 %d 段 / 4。%s"
flavor = "{act["flavor"]}"
combat_enemies = Array[String]([{combat_str}])
elite_enemies = Array[String]([{elite_str}])
fixed_nodes = Array[MapNodeData]([{fixed_str}])
act_boss_name = "{act["boss_name"]}"
act_boss_title = "{act["boss_title"]}"
act_boss_body = "{act["boss_body"]}"
is_final_act = {"true" if act["final"] else "false"}
'''
    path.write_text(content, encoding="utf-8")


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "data" / "acts"
    out.mkdir(parents=True, exist_ok=True)
    for act in ACTS:
        write_act(out / f"{act['id']}.tres", act)
        print(out / f"{act['id']}.tres")


if __name__ == "__main__":
    main()
