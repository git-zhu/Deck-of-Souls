"""Generate data/grace_options/*.tres (UTF-8)."""
from pathlib import Path

OPTIONS = [
    {
        "file": "rest",
        "id": "rest",
        "title": "休憩",
        "body": "在赐福金光下休息，回复部分生命并补满圣杯瓶。",
        "effect": "heal_percent",
        "effect_value": 35,
        "soul_cost": 0,
        "card_id": "",
        "min_deck_size": 0,
    },
    {
        "file": "vitality",
        "id": "vitality",
        "title": "熔炉百相·生命力",
        "body": "以熔炉百相塑形，最大生命提升 8 点。",
        "effect": "max_hp",
        "effect_value": 8,
        "soul_cost": 0,
        "card_id": "",
        "min_deck_size": 0,
    },
    {
        "file": "kindling",
        "id": "kindling",
        "title": "添火",
        "body": "在赐福旁添火，圣杯瓶上限 +1（最多 5）。",
        "effect": "max_flasks",
        "effect_value": 1,
        "soul_cost": 0,
        "card_id": "",
        "min_deck_size": 0,
    },
    {
        "file": "purge",
        "id": "purge",
        "title": "遗忘仪式",
        "body": "从牌组中永久移除一张牌。",
        "effect": "remove_card",
        "effect_value": 0,
        "soul_cost": 0,
        "card_id": "",
        "min_deck_size": 6,
    },
    {
        "file": "clarity",
        "id": "clarity",
        "title": "净化",
        "body": "赐福洗净腐败、出血与易伤。",
        "effect": "clear_debuffs",
        "effect_value": 0,
        "soul_cost": 0,
        "card_id": "",
        "min_deck_size": 0,
    },
    {
        "file": "destined_death",
        "id": "destined_death",
        "title": "窥见命定之死",
        "body": "消耗 45 卢恩，将《命定之死》加入牌组。",
        "effect": "add_card",
        "effect_value": 0,
        "soul_cost": 45,
        "card_id": "destined_death",
        "min_deck_size": 0,
    },
]


def write_option(path: Path, opt: dict) -> None:
    content = f"""[gd_resource type="Resource" script_class="GraceOptionData" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/GraceOptionData.gd" id="1"]

[resource]
script = ExtResource("1")
id = "{opt["id"]}"
title = "{opt["title"]}"
body = "{opt["body"]}"
effect = "{opt["effect"]}"
effect_value = {opt["effect_value"]}
soul_cost = {opt["soul_cost"]}
card_id = "{opt["card_id"]}"
min_deck_size = {opt["min_deck_size"]}
"""
    path.write_text(content, encoding="utf-8")


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "data" / "grace_options"
    out.mkdir(parents=True, exist_ok=True)
    for opt in OPTIONS:
        p = out / f"{opt['file']}.tres"
        write_option(p, opt)
        print(p)


if __name__ == "__main__":
    main()
