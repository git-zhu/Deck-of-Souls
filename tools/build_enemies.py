"""Patch data/enemies/*.tres max_hp and souls from canonical table (UTF-8)."""
import re
from pathlib import Path

# Chinese display name -> (max_hp, souls)
ENEMY_STATS: dict[str, tuple[int, int]] = {
    "野狼": (30, 12),
    "葛瑞克士兵": (38, 14),
    "凯丹佣兵": (48, 22),
    "挖石矿工": (40, 18),
    "学院辉石法师": (44, 20),
    "亚人": (34, 16),
    "葛瑞克骑士": (52, 26),
    "腐败眷属": (46, 22),
    "法姆亚兹拉的兽人": (68, 45),
    "亚人首领": (70, 46),
    "挖石山妖": (74, 48),
    "守墓斗士": (72, 48),
    "熔炉骑士": (108, 100),
    "恶兆妖鬼玛尔基特": (110, 120),
    "接肢贵族": (130, 180),
    "大树守卫": (58, 28),
    "狮子混种": (50, 24),
    "坠星兽": (78, 50),
}


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    match = re.search(r'^name = "(.+)"', text, re.MULTILINE)
    if not match:
        print(f"skip (no name): {path}")
        return False
    name = match.group(1)
    if name not in ENEMY_STATS:
        print(f"skip (unknown): {path} {name}")
        return False
    max_hp, souls = ENEMY_STATS[name]
    new_text = re.sub(r"max_hp = \d+", f"max_hp = {max_hp}", text, count=1)
    new_text = re.sub(r"souls = \d+", f"souls = {souls}", new_text, count=1)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        print(f"patched {path.name}: {name} hp={max_hp} souls={souls}")
        return True
    print(f"unchanged {path.name}")
    return False


def main() -> None:
    enemies_dir = Path(__file__).resolve().parent.parent / "data" / "enemies"
    for path in sorted(enemies_dir.glob("*.tres")):
        patch_file(path)


if __name__ == "__main__":
    main()
