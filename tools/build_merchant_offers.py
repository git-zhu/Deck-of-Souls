"""Generate data/merchant_offers/*.tres (UTF-8)."""
from pathlib import Path

OFFERS = [
    {
        "file": "curio_card",
        "id": "curio_card",
        "title": "咖列的货箱",
        "body": "一只上了锁的木箱，里面是褪色者常用的战法卡牌。",
        "effect": "add_random_card",
        "effect_value": 0,
        "soul_cost": 50,
        "min_deck_size": 0,
        "card_rarity_filter": "",
    },
    {
        "file": "remove_card",
        "id": "remove_card",
        "title": "整理行囊",
        "body": "付费请咖列帮你丢掉一张碍事的牌。",
        "effect": "remove_card",
        "effect_value": 0,
        "soul_cost": 75,
        "min_deck_size": 6,
        "card_rarity_filter": "",
    },
    {
        "file": "blood_vial",
        "id": "blood_vial",
        "title": "血污圣杯瓶",
        "body": "残血兑来的试饮，能回复部分生命。",
        "effect": "heal_percent",
        "effect_value": 25,
        "soul_cost": 35,
        "min_deck_size": 0,
        "card_rarity_filter": "",
    },
    {
        "file": "refill_flasks",
        "id": "refill_flasks",
        "title": "装满圣杯瓶",
        "body": "咖列替你灌满圣杯瓶里的红露滴。",
        "effect": "refill_flasks",
        "effect_value": 0,
        "soul_cost": 30,
        "min_deck_size": 0,
        "card_rarity_filter": "",
    },
    {
        "file": "kindling_sale",
        "id": "kindling_sale",
        "title": "添火材料",
        "body": "一小袋引火绒，能在赐福旁多添一把火。",
        "effect": "max_flasks",
        "effect_value": 1,
        "soul_cost": 40,
        "min_deck_size": 0,
        "card_rarity_filter": "",
    },
    {
        "file": "scrap_paper",
        "id": "scrap_paper",
        "title": "褪色者护符",
        "body": "咖列从货箱底层摸出一件未绑定的护符，卖给有缘的褪色者。",
        "effect": "grant_relic",
        "effect_value": 0,
        "soul_cost": 55,
        "min_deck_size": 0,
        "card_rarity_filter": "",
    },
    {
        "file": "memory_stone",
        "id": "memory_stone",
        "title": "记忆石",
        "body": "蕾亚卢卡利亚风格的记忆石，能拓展战斗中的施法记忆槽位。",
        "effect": "memory_stone",
        "effect_value": 0,
        "soul_cost": 65,
        "min_deck_size": 0,
        "card_rarity_filter": "",
    },
    {
        "file": "ash_replace",
        "id": "ash_replace",
        "title": "战灰传授",
        "body": "咖列演示战灰技法：选一张牌被覆盖，再从三张战灰中选一张替换。",
        "effect": "ash_replace",
        "effect_value": 0,
        "soul_cost": 70,
        "min_deck_size": 6,
        "card_rarity_filter": "",
    },
]


def write_offer(path: Path, offer: dict) -> None:
    content = f"""[gd_resource type="Resource" script_class="MerchantOfferData" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/MerchantOfferData.gd" id="1"]

[resource]
script = ExtResource("1")
id = "{offer["id"]}"
title = "{offer["title"]}"
body = "{offer["body"]}"
effect = "{offer["effect"]}"
effect_value = {offer["effect_value"]}
soul_cost = {offer["soul_cost"]}
min_deck_size = {offer["min_deck_size"]}
card_rarity_filter = "{offer["card_rarity_filter"]}"
"""
    path.write_text(content, encoding="utf-8")


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "data" / "merchant_offers"
    out.mkdir(parents=True, exist_ok=True)
    for offer in OFFERS:
        p = out / f"{offer['file']}.tres"
        write_offer(p, offer)
        print(p)


if __name__ == "__main__":
    main()
