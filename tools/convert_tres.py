#!/usr/bin/env python3
"""Convert legacy [resource name=...] .tres files to Godot 4 gd_resource format."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

CARD_SCRIPT = "res://data/CardData.gd"
ORIGIN_SCRIPT = "res://data/OriginData.gd"
ENEMY_SCRIPT = "res://data/EnemyData.gd"
MOVE_SCRIPT = "res://data/MoveData.gd"


def _format_prop(key: str, raw: str) -> str:
    value = raw.strip()
    if value.startswith('"') and value.endswith('"'):
        return f'{key} = {value}'
    if value.startswith("Color("):
        return f"{key} = {value}"
    if value.startswith("[") and "^" in value:
        refs = re.findall(r"\^(\w+)", value)
        subs = ", ".join(f'SubResource("{r}")' for r in refs)
        return f"{key} = [{subs}]"
    if value.startswith("["):
        return f"{key} = {value}"
    if value in ("true", "false"):
        return f"{key} = {value}"
    if re.fullmatch(r"-?\d+", value):
        return f"{key} = {value}"
    return f'{key} = "{value}"'


def _parse_props(lines: list[str]) -> list[str]:
    props: list[str] = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("["):
            continue
        if "=" not in line:
            continue
        key, raw = line.split("=", 1)
        props.append(_format_prop(key.strip(), raw))
    return props


def convert_card_or_origin(text: str, script_class: str, script_path: str) -> str:
    props = _parse_props(text.splitlines())
    header = (
        f'[gd_resource type="Resource" script_class="{script_class}" '
        f"load_steps=2 format=3]\n\n"
        f'[ext_resource type="Script" path="{script_path}" id="1"]\n\n'
        f"[resource]\n"
        f'script = ExtResource("1")\n'
    )
    return header + "\n".join(props) + "\n"


def convert_enemy(text: str) -> str:
    lines = text.splitlines()
    sub_blocks: list[tuple[str, list[str]]] = []
    main_lines: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("[sub_resource"):
            m = re.search(r'id="([^"]+)"', line)
            sub_id = m.group(1) if m else f"MoveData_{len(sub_blocks)}"
            i += 1
            block: list[str] = []
            while i < len(lines):
                nxt = lines[i].strip()
                if nxt.startswith("[sub_resource") or nxt.startswith("[resource"):
                    break
                if nxt:
                    block.append(lines[i])
                i += 1
            sub_blocks.append((sub_id, block))
            continue
        if line.startswith("[resource"):
            i += 1
            while i < len(lines):
                nxt = lines[i].strip()
                if nxt.startswith("["):
                    break
                if nxt:
                    main_lines.append(lines[i])
                i += 1
            continue
        i += 1

    load_steps = 2 + len(sub_blocks)
    parts = [
        f'[gd_resource type="Resource" script_class="EnemyData" load_steps={load_steps} format=3]',
        "",
        f'[ext_resource type="Script" path="{ENEMY_SCRIPT}" id="1"]',
        f'[ext_resource type="Script" path="{MOVE_SCRIPT}" id="2"]',
        "",
    ]
    for sub_id, block in sub_blocks:
        props = _parse_props(block)
        parts.append(f'[sub_resource type="Resource" id="{sub_id}"]')
        parts.append('script = ExtResource("2")')
        parts.extend(props)
        parts.append("")
    props = _parse_props(main_lines)
    parts.append("[resource]")
    parts.append('script = ExtResource("1")')
    parts.extend(props)
    return "\n".join(parts) + "\n"


def convert_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if text.startswith("[gd_resource"):
        return False
    if path.parent.name == "cards":
        new_text = convert_card_or_origin(text, "CardData", CARD_SCRIPT)
    elif path.parent.name == "origins":
        new_text = convert_card_or_origin(text, "OriginData", ORIGIN_SCRIPT)
    elif path.parent.name == "enemies":
        new_text = convert_enemy(text)
    else:
        return False
    path.write_text(new_text, encoding="utf-8", newline="\n")
    return True


def main() -> None:
    changed = 0
    for folder in ("cards", "origins", "enemies"):
        for path in sorted((DATA / folder).glob("*.tres")):
            if convert_file(path):
                changed += 1
                print(f"converted {path.relative_to(ROOT)}")
    print(f"done: {changed} files")


if __name__ == "__main__":
    main()
