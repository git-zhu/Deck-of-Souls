"""Generate data/events/*.tres (UTF-8)."""
from pathlib import Path

EVENTS = [
    {
        "file": "limgrave_corpse",
        "id": "limgrave_corpse",
        "title": "褪色者遗骸",
        "body": "路旁躺着一具同样穿着褪色者装束的尸体，口袋鼓鼓，武器却不见了。",
        "choices": [
            {
                "id": "loot",
                "label": "搜刮遗骸",
                "effect": "gain_souls",
                "effect_value": 25,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
            {
                "id": "pray",
                "label": "敬拜逝者",
                "effect": "max_hp",
                "effect_value": 6,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
            {
                "id": "leave",
                "label": "悄然离开",
                "effect": "nothing",
                "effect_value": 0,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
        ],
    },
    {
        "file": "limgrave_beggar",
        "id": "limgrave_beggar",
        "title": "流浪乞儿",
        "body": "乞儿向每个路过的褪色者伸手。他的眼睛在头盔下闪了闪。",
        "choices": [
            {
                "id": "alms",
                "label": "施舍 20 卢恩",
                "effect": "heal_percent",
                "effect_value": 15,
                "soul_cost": 20,
                "card_id": "",
                "min_deck_size": 0,
            },
            {
                "id": "ignore",
                "label": "无视走开",
                "effect": "nothing",
                "effect_value": 0,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
        ],
    },
    {
        "file": "stormveil_armory",
        "id": "stormveil_armory",
        "title": "废弃军械库",
        "body": "城墙夹层里堆着生锈的武器。角落里似乎还连着某种机关。",
        "choices": [
            {
                "id": "take_axe",
                "label": "拿走战斧",
                "effect": "add_card",
                "effect_value": 0,
                "soul_cost": 0,
                "card_id": "battle_axe",
                "min_deck_size": 0,
            },
            {
                "id": "trap",
                "label": "翻找货架",
                "effect": "damage_percent",
                "effect_value": 15,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
        ],
    },
    {
        "file": "stormveil_shrine",
        "id": "stormveil_shrine",
        "title": "英雄墓旁祭坛",
        "body": "墓碑间的祭坛仍有余温。黄金树的光从垛口斜照进来。",
        "choices": [
            {
                "id": "flask",
                "label": "饮尽祭坛残露",
                "effect": "refill_flasks",
                "effect_value": 0,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
            {
                "id": "offer",
                "label": "献祭 30 卢恩",
                "effect": "max_hp",
                "effect_value": 8,
                "soul_cost": 30,
                "card_id": "",
                "min_deck_size": 0,
            },
        ],
    },
    {
        "file": "liurnia_scholar",
        "id": "liurnia_scholar",
        "title": "落灰学者",
        "body": "学者蹲在遗迹台阶上抄写辉石符文。他抬头看你一眼，又低下头去。",
        "choices": [
            {
                "id": "copy",
                "label": "抄录符文",
                "effect": "add_card",
                "effect_value": 0,
                "soul_cost": 0,
                "card_id": "glintstone_arc",
                "min_deck_size": 0,
            },
            {
                "id": "disturb",
                "label": "打断他的工作",
                "effect": "damage_percent",
                "effect_value": 10,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
        ],
    },
    {
        "file": "liurnia_drowned",
        "id": "liurnia_drowned",
        "title": "溺水教堂遗声",
        "body": "湖底升起的回音像祷词又像诅咒。金光在门外拦住寒气。",
        "choices": [
            {
                "id": "listen",
                "label": "聆听回音",
                "effect": "gain_souls",
                "effect_value": 20,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
            {
                "id": "rest",
                "label": "在门廊休息",
                "effect": "heal_percent",
                "effect_value": 25,
                "soul_cost": 0,
                "card_id": "",
                "min_deck_size": 0,
            },
        ],
    },
]


def write_event(path: Path, event: dict) -> None:
    choice_blocks: list[str] = []
    choice_refs: list[str] = []
    for i, ch in enumerate(event["choices"]):
        choice_blocks.append(
            f'''[sub_resource type="Resource" id="Choice_{i}"]
script = ExtResource("2")
id = "{ch["id"]}"
label = "{ch["label"]}"
effect = "{ch["effect"]}"
effect_value = {ch["effect_value"]}
soul_cost = {ch["soul_cost"]}
card_id = "{ch["card_id"]}"
min_deck_size = {ch["min_deck_size"]}
'''
        )
        choice_refs.append(f'SubResource("Choice_{i}")')
    choices_arr = ", ".join(choice_refs)
    load_steps = len(event["choices"]) + 3
    content = f'''[gd_resource type="Resource" script_class="MapEventData" load_steps={load_steps} format=3]

[ext_resource type="Script" path="res://data/MapEventData.gd" id="1"]
[ext_resource type="Script" path="res://data/MapEventChoiceData.gd" id="2"]

{"".join(choice_blocks)}
[resource]
script = ExtResource("1")
id = "{event["id"]}"
title = "{event["title"]}"
body = "{event["body"]}"
choices = Array[MapEventChoiceData]([{choices_arr}])
'''
    path.write_text(content, encoding="utf-8")


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "data" / "events"
    out.mkdir(parents=True, exist_ok=True)
    for event in EVENTS:
        p = out / f"{event['file']}.tres"
        write_event(p, event)
        print(p)


if __name__ == "__main__":
    main()
