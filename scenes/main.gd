extends Node2D

# いまは「1日目の試作」の第1歩：作中タイトル（神経衰弱 v1.3）を単体で遊べる確認用画面。
# 画面下の開発用スイッチで、バグを1つずつ ON/OFF してプレイし直せる。
# UI 文字列は ASCII のみにすること（Godot 標準フォントに日本語グリフが無く
# Web だと豆腐になる。日本語を出したいなら日本語フォントを同梱してテーマに設定）。

const BUGS_PATH := "res://data/bugs.json"

# 有効にしているバグの ID（最初は全部 ON＝1日目の本番と同じ）
var enabled: Array = []
var bug_ids: Array = []

@onready var game: MemoryMatch = $HUD/MemoryMatch
@onready var switches: HBoxContainer = $HUD/DevPanel/Switches
@onready var restart_button: Button = $HUD/DevPanel/Restart


func _ready() -> void:
	for bug in _load_bugs():
		bug_ids.append(bug.id)
	enabled = bug_ids.duplicate()
	for id in bug_ids:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = true
		b.custom_minimum_size = Vector2(200, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.toggled.connect(_on_switch_toggled.bind(id, b))
		_update_switch_text(b, id, true)
		switches.add_child(b)
	restart_button.pressed.connect(_restart)
	_restart()


func _load_bugs() -> Array:
	var text := FileAccess.get_file_as_string(BUGS_PATH)
	var data = JSON.parse_string(text)
	if data == null:
		push_error("bugs.json が読めない")
		return []
	return data.bugs


func _on_switch_toggled(on: bool, id: String, b: Button) -> void:
	if on and not enabled.has(id):
		enabled.append(id)
	elif not on:
		enabled.erase(id)
	_update_switch_text(b, id, on)
	_restart()


func _update_switch_text(b: Button, id: String, on: bool) -> void:
	b.text = "%s %s" % [id.trim_prefix("MM-HW-"), "ON" if on else "OFF"]


func _restart() -> void:
	game.start(enabled)
