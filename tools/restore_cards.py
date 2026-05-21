"""Rewrite card .tres files with valid UTF-8 (fixes PowerShell encoding damage)."""
from pathlib import Path

# id -> (name, cost, type, rarity, text, tone rgba 0-1, hook_id, exhaust)
CARDS = {
    "longsword": ("长剑", 1, "武器", "starter", "造成 7 点伤害，削减 3 姿态。流浪骑士的可靠起手。", (0.725, 0.640, 0.482, 1), "", False),
    "heater_shield": ("熨斗形盾", 1, "盾牌", "starter", "获得 8 护甲。若敌人意图攻击，返还 1 集中。", (0.490, 0.612, 0.639, 1), "heater_shield", False),
    "halberd": ("戟", 2, "武器", "starter", "造成 13 点伤害，削减 5 姿态。长柄武器让距离成为护甲。", (0.753, 0.627, 0.424, 1), "", False),
    "uchigatana": ("打刀", 1, "武器", "starter", "造成 6 点伤害，积累 5 出血。芦苇之地武士的弯刃。", (0.725, 0.294, 0.314, 1), "", False),
    "longbow": ("长弓", 1, "武器", "starter", "造成 5 点伤害。若敌人没有护甲，抽 1 张牌。", (0.612, 0.518, 0.345, 1), "longbow", False),
    "scimitar": ("弯刀", 1, "武器", "starter", "造成 4 点伤害两次。战士以双刀寻找破绽。", (0.718, 0.627, 0.443, 1), "", False),
    "battle_axe": ("战斧", 2, "武器", "starter", "造成 15 点伤害。若破姿态，获得 1 点集中。", (0.788, 0.514, 0.294, 1), "battle_axe", False),
    "great_knife": ("伟大匕首", 0, "武器", "common", "造成 3 点伤害，积累 3 出血。匕首在阴影里更快。", (0.647, 0.529, 0.529, 1), "", False),
    "buckler": ("小圆盾", 1, "盾牌", "starter", "获得 5 护甲。若敌人意图攻击，削减 4 姿态。", (0.529, 0.608, 0.604, 1), "buckler", False),
    "glintstone_pebble": ("辉石魔砾", 1, "魔法", "starter", "造成 4 点伤害两次。观星者的第一颗辉石。", (0.482, 0.627, 0.878, 1), "", False),
    "glintstone_arc": ("辉石弯弧", 2, "魔法", "starter", "造成 10 点伤害，削减 4 姿态。弧形辉石划过雾中。", (0.482, 0.627, 0.878, 1), "", False),
    "magic_glintblade": ("魔法辉剑", 1, "魔法", "starter", "造成 8 点伤害。若本回合还剩集中，追加 3 点伤害。", (0.482, 0.627, 0.878, 1), "magic_glintblade", False),
    "catch_flame": ("火焰啊！", 2, "祷告", "starter", "造成 9 点伤害，削减 3 姿态。巨人火焰的祷告。", (0.851, 0.757, 0.427, 1), "", False),
    "heal": ("恢复", 2, "祷告", "starter", "回复 8 生命，获得 3 护甲。双指信仰留下喘息。", (0.851, 0.757, 0.427, 1), "", False),
    "urgent_heal": ("紧急恢复", 1, "祷告", "starter", "回复 5 生命。若生命低于一半，抽 1 张牌。", (0.871, 0.812, 0.510, 1), "urgent_heal", False),
    "assassins_approach": ("刺客步法", 1, "战灰", "common", "获得 4 护甲，抽 1 张牌。无声脚步贴近后背。", (0.647, 0.647, 0.647, 1), "", False),
    "lions_claw": ("狮子斩", 2, "战灰", "common", "造成 14 点伤害，削减 5 姿态。源自红狮子军的翻身重击。", (0.827, 0.631, 0.255, 1), "lions_claw", False),
    "club": ("棍棒", 1, "武器", "starter", "造成 6 点伤害。若这是手牌最后一张，伤害 +5。", (0.608, 0.478, 0.333, 1), "club", False),
    "volcano_pot": ("火山壶", 1, "壶", "uncommon", "造成 6 点伤害，施加 2 易伤。滚烫陶片在敌人身上炸裂。", (0.788, 0.420, 0.255, 1), "", False),
    "rotten_breath": ("腐败吐息", 2, "祷告", "uncommon", "对敌人施加 6 腐败。菌类气息缠住喉咙。", (0.529, 0.608, 0.420, 1), "", False),
    "black_flame": ("黑焰", 2, "祷告", "uncommon", "造成 12 点伤害，并施加 3 易伤。神皮使徒的火会继续灼烧。", (0.365, 0.353, 0.396, 1), "", False),
    "bloodhounds_step": ("猎犬步法", 1, "战灰", "common", "获得 4 护甲，抽 1 张牌。血指猎人留下的闪步。", (0.647, 0.529, 0.529, 1), "", False),
    "crimson_flask": ("红露滴圣杯瓶", 0, "圣杯瓶", "rare", "回复 12 生命。消耗。赐福分配给褪色者的红色瓶子。", (0.847, 0.357, 0.310, 1), "", True),
    "destined_death": ("命定之死", 3, "传说", "rare", "造成 25 点伤害。若击杀敌人，永久获得 +4 最大生命。", (0.608, 0.482, 0.816, 1), "destined_death", False),
}


def write_card(path: Path, row: tuple) -> None:
    cid, name, cost, ctype, rarity, text, tone, hook, exhaust = row
    cid_key = path.stem
    body = f'''[resource name="CardData"]
id="{cid_key}"
name="{name}"
cost={cost}
type="{ctype}"
rarity="{rarity}"
text="{text}"
tone=Color({tone[0]}, {tone[1]}, {tone[2]}, 1)
hook_id="{hook}"
exhaust_after_play={"true" if exhaust else "false"}
'''
    path.write_text(body, encoding="utf-8")


def main() -> None:
    cards_dir = Path(__file__).resolve().parent.parent / "data" / "cards"
    for path in sorted(cards_dir.glob("*.tres")):
        key = path.stem
        if key in CARDS:
            write_card(path, (key, *CARDS[key]))
            print(path.name)


if __name__ == "__main__":
    main()
