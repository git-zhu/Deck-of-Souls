class_name CombatHudRefs
extends RefCounted

var root: Control
var player_panel: PanelContainer
var enemy_panel: PanelContainer
# 全部敌人面板（index → PanelContainer）：多敌人飘字/血条动画/意图用
var enemy_panels: Dictionary = {}
var log_box: RichTextLabel
var hand_row: HBoxContainer
var flask_button: Button
var end_turn_button: Button
