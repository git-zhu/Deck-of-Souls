"""Generate data/acts/*.tres with MapNodeData, MapEncounterData (UTF-8)."""
from pathlib import Path

# Shared encounter copy (migrated from MapGenerator COMBAT_NODES / ELITE_NODES)
COMBAT_META = {
    "葛瑞克士兵": ("关卡前废墟", "葛瑞克士兵巡逻。胜利后获得一张牌与少量卢恩。"),
    "野狼": ("艾雷教堂北侧", "野狼在林间徘徊，商人咖列的篝火还在身后。"),
    "凯丹佣兵": ("亚基尔湖北岸", "凯丹佣兵沿湖道游荡，远处能听见飞龙亚基尔的风声。"),
    "挖石矿工": ("宁姆格福坑道", "挖石矿工守着锻造石，矿镐比看上去更硬。"),
    "学院辉石法师": ("驿站街遗迹", "学院辉石法师藏在废墟地下，辉石光芒从石缝里透出。"),
    "葛瑞克骑士": ("史东薇尔城墙", "葛瑞克骑士巡逻于城墙之上，铠甲上还带着宁姆格福的泥。"),
    "腐败眷属": ("腐败湖畔", "腐败眷属在湖畔蠕动，金色的菌丝缠住脚踝。"),
    "挖石山妖": ("坑道深处", "挖石山妖在矿道底层抬起巨臂，碎石从顶上落下。"),
    "亚人": ("海岸洞窟入口", "亚人在洞口聚集，棍棒敲打石壁的声音令人不安。"),
}

ELITE_META = {
    "法姆亚兹拉的兽人": ("近林洞窟", "法姆亚兹拉的兽人盘踞洞底，这是许多褪色者的第一个洞窟首领。"),
    "亚人首领": ("海岸洞窟", "亚人首领在黑暗中聚众嚎叫，洞外通向龙飨教堂。"),
    "熔炉骑士": ("封牢深处", "熔炉骑士的古老武艺仍在回响。"),
    "守墓斗士": ("英雄墓地", "守墓斗士守在墓碑之间，巨斧扬起时风声如哭。"),
}


def _encounter_block(idx: int, enemy: str, title: str, body: str) -> tuple[str, str]:
    block = f'''[sub_resource type="Resource" id="Enc_{idx}"]
script = ExtResource("3")
enemy_name = "{enemy}"
title = "{title}"
body = "{body}"
'''
    return block, f'SubResource("Enc_{idx}")'


def _combat_list(names: list[str]) -> list[tuple[str, str, str]]:
    out = []
    for name in names:
        title, body = COMBAT_META.get(name, (name, "一场遭遇战。"))
        out.append((name, title, body))
    return out


def _elite_list(names: list[str]) -> list[tuple[str, str, str]]:
    out = []
    for name in names:
        if name in ELITE_META:
            title, body = ELITE_META[name]
        elif name in COMBAT_META:
            title, body = COMBAT_META[name]
        else:
            title, body = name, "精英敌人挡在路前。"
        out.append((name, title, body))
    return out


ACTS = [
    {
        "id": "limgrave",
        "title": "宁姆格福路标",
        "flavor": "沿赐福指引穿过风暴山丘，接近候王礼拜堂的阴影。",
        "combat": _combat_list(
            ["葛瑞克士兵", "野狼", "凯丹佣兵", "挖石矿工", "学院辉石法师", "亚人"]
        ),
        "elite": _elite_list(["法姆亚兹拉的兽人", "亚人首领", "挖石山妖"]),
        "reward_cards": [
            "great_knife",
            "bloodhounds_step",
            "assassins_approach",
            "scimitar",
            "catch_flame",
            "rock_sling",
        ],
        "enemy_hp_percent": 100,
        "grace": [
            ("赐福点", "回复生命，补充圣杯瓶，或用卢恩触碰命定之死。"),
            ("艾雷教堂", "短暂停歇。锻造台旁的金光提醒你整理牌组。"),
        ],
        "merchant": [
            ("商人咖列", "流浪商人坐在熄灭篝火旁，货箱上贴着褪色者也能看懂的价签。"),
        ],
        "event_ids": ["limgrave_corpse", "limgrave_beggar"],
        "boss_name": "恶兆妖鬼玛尔基特",
        "boss_title": "通城隧道",
        "boss_body": "恶兆妖鬼玛尔基特守在史东薇尔城前。穿过这道雾门，宁姆格福的开局才算结束。",
        "final": False,
    },
    {
        "id": "stormveil",
        "title": "史东薇尔城塞",
        "flavor": "城墙内回荡着接肢的金属声，黄金树的枝桠在雾上摇晃。",
        "combat": _combat_list(["葛瑞克骑士", "腐败眷属", "挖石山妖", "凯丹佣兵"]),
        "elite": _elite_list(["熔炉骑士", "守墓斗士", "挖石山妖"]),
        "reward_cards": [
            "lions_claw",
            "black_flame",
            "rotten_breath",
            "battle_axe",
            "longbow",
            "hoarfrost_stomp",
        ],
        "enemy_hp_percent": 110,
        "grace": [
            ("城墙赐福", "在狭窄走廊里喘息，整理被撕破的战意。"),
            ("格密尔英雄墓", "墓碑旁的金光让你想起尚未完成的誓言。"),
        ],
        "merchant": [
            ("城墙下的咖列", "咖列把货箱藏在垛口后，只卖给还能喘气的褪色者。"),
        ],
        "event_ids": ["stormveil_armory", "stormveil_shrine"],
        "boss_name": "熔炉骑士",
        "boss_title": "风暴山丘封牢",
        "boss_body": "熔炉骑士的古老武艺仍在回响。击败他，城塞的大门才会松动。",
        "final": False,
    },
    {
        "id": "liurnia",
        "title": "湖之利耶尼亚",
        "flavor": "金色倒影铺在湖面，学院与教堂的钟声在雾中重叠。",
        "combat": _combat_list(["学院辉石法师", "腐败眷属", "葛瑞克骑士", "凯丹佣兵"]),
        "elite": _elite_list(["熔炉骑士", "守墓斗士", "挖石山妖"]),
        "reward_cards": [
            "glintstone_arc",
            "volcano_pot",
            "catch_flame",
            "destined_death",
            "magic_glintblade",
            "rock_sling",
            "flame_grant_me_strength",
            "glintstone_stars",
        ],
        "enemy_hp_percent": 125,
        "grace": [
            ("学院门前赐福", "辉石光芒退入石缝，你得以审视自己的牌路。"),
            ("教堂侧廊", "溺水教堂的寒气被金光挡在门外。"),
        ],
        "merchant": [
            ("湖畔咖列", "咖列把船系在教堂遗迹旁，高价收购卢恩，低价卖出麻烦。"),
        ],
        "event_ids": ["liurnia_scholar", "liurnia_drowned"],
        "boss_name": "接肢贵族",
        "boss_title": "贵族厅堂",
        "boss_body": "接肢贵族在湖底厅堂等待。胜利意味着这趟褪色旅程暂时落幕。",
        "final": True,
    },
]


def write_act(path: Path, act: dict) -> None:
    blocks: list[str] = []
    refs: list[str] = []
    idx = 0

    combat_refs: list[str] = []
    for enemy, title, body in act["combat"]:
        block, ref = _encounter_block(idx, enemy, title, body)
        blocks.append(block)
        combat_refs.append(ref)
        idx += 1

    elite_refs: list[str] = []
    for enemy, title, body in act["elite"]:
        block, ref = _encounter_block(idx, enemy, title, body)
        blocks.append(block)
        elite_refs.append(ref)
        idx += 1

    for title, body in act.get("grace", []):
        blocks.append(
            f'''[sub_resource type="Resource" id="Node_{idx}"]
script = ExtResource("2")
kind = "grace"
title = "{title}"
body = "{body}"
'''
        )
        refs.append(f'SubResource("Node_{idx}")')
        idx += 1

    for title, body in act.get("merchant", []):
        blocks.append(
            f'''[sub_resource type="Resource" id="Node_{idx}"]
script = ExtResource("2")
kind = "merchant"
title = "{title}"
body = "{body}"
'''
        )
        refs.append(f'SubResource("Node_{idx}")')
        idx += 1

    reward_str = ", ".join(f'"{c}"' for c in act["reward_cards"])
    event_str = ", ".join(f'"{e}"' for e in act.get("event_ids", []))
    fixed_str = ", ".join(refs)
    combat_arr = ", ".join(combat_refs)
    elite_arr = ", ".join(elite_refs)
    load_steps = idx + 4

    content = f'''[gd_resource type="Resource" script_class="ActData" load_steps={load_steps} format=3]

[ext_resource type="Script" path="res://data/ActData.gd" id="1"]
[ext_resource type="Script" path="res://data/MapNodeData.gd" id="2"]
[ext_resource type="Script" path="res://data/MapEncounterData.gd" id="3"]

{"".join(blocks)}
[resource]
script = ExtResource("1")
id = "{act["id"]}"
title = "{act["title"]}"
subtitle_template = "第 %d 段 / 4。%s"
flavor = "{act["flavor"]}"
combat_encounters = Array[MapEncounterData]([{combat_arr}])
elite_encounters = Array[MapEncounterData]([{elite_arr}])
reward_cards = Array[String]([{reward_str}])
event_ids = Array[String]([{event_str}])
fixed_nodes = Array[MapNodeData]([{fixed_str}])
act_boss_name = "{act["boss_name"]}"
act_boss_title = "{act["boss_title"]}"
act_boss_body = "{act["boss_body"]}"
is_final_act = {"true" if act["final"] else "false"}
enemy_hp_percent = {act.get("enemy_hp_percent", 100)}
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
