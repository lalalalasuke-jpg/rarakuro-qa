extends Node2D

# 1日目の試作：オフィスの画面。
# 上＝ヘッダーとリーダーからのチャット、真ん中＝モニター（作中タイトルが動く）、下＝机（仕様メモなど）。
# その日の担当は data/day1.json、仕様メモの中身は data/spec_*.json、バグは data/bugs.json。
# 日本語は fonts/NotoSansJP-Subset.ttf（project.godot でテーマの標準フォントに設定）で表示できる。

const BUGS_PATH := "res://data/bugs.json"
const DAY_PATH := "res://data/day1.json"

var day: Dictionary
var spec: Dictionary
# 有効にしているバグの ID（最初はその日の設定どおり）
var enabled: Array = []

@onready var game: MemoryMatch = $HUD/Monitor/MemoryMatch
@onready var day_label: Label = $HUD/Header/DayLabel
@onready var chat_from: Label = $HUD/Chat/From
@onready var chat_text: Label = $HUD/Chat/Bubble/Text
@onready var memo: SpecMemo = $HUD/SpecMemo
@onready var memo_button: Button = $HUD/Desk/MemoButton
@onready var dev_button: Button = $HUD/Header/DevButton
@onready var dev_panel: Control = $HUD/DevPanel
@onready var switches: HBoxContainer = $HUD/DevPanel/Switches
@onready var restart_button: Button = $HUD/DevPanel/Restart


func _ready() -> void:
	day = _load_json(DAY_PATH)
	spec = _load_json(day.spec)
	enabled = day.bugs.duplicate()

	day_label.text = "%d日目　朝" % day.day
	chat_from.text = day.chat_from
	chat_text.text = day.chat
	memo_button.pressed.connect(func(): memo.show_spec(spec))

	_build_dev_switches()
	dev_button.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)
	restart_button.pressed.connect(_restart)
	_restart()


func _load_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("%s が読めない" % path)
		return {}
	return data


# 開発用：バグを1つずつ ON/OFF してプレイし直せるスイッチ（本番では隠す）
func _build_dev_switches() -> void:
	for bug in _load_json(BUGS_PATH).bugs:
		var id: String = bug.id
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = enabled.has(id)
		b.custom_minimum_size = Vector2(200, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.toggled.connect(_on_switch_toggled.bind(id, b))
		_update_switch_text(b, id, b.button_pressed)
		switches.add_child(b)


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
