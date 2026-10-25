extends Node2D

# 1日目の試作：オフィスの画面。
# 上＝ヘッダーとリーダーからのチャット、真ん中＝モニター（作中タイトルが動く）、下＝机（仕様メモなど）。
# その日の担当は data/day1.json、仕様メモの中身は data/spec_*.json、バグは data/bugs.json。
# 日本語は fonts/NotoSansJP-Subset.ttf（project.godot でテーマの標準フォントに設定）で表示できる。

const BUGS_PATH := "res://data/bugs.json"
const DAY_PATH := "res://data/day1.json"

const CHAT_NOT_SEEN := "その現象、まだ画面で確認できてないみたい。実際に起きるのを見てから報告してね。"
const CHAT_SUBMITTED := "報告ありがとう！開発さんに渡しておくね。返事は明日届くよ。"

var day: Dictionary
var spec: Dictionary
var bugs: Array = []
var report_options: Dictionary
# 有効にしているバグの ID（最初はその日の設定どおり）
var enabled: Array = []
# プレイヤーが画面で見たバグの ID
var observed: Array = []
# 提出した報告（{report, judge}）と、報告済みのバグ ID
var reports: Array = []
var reported: Array = []

@onready var game: MemoryMatch = $HUD/Monitor/MemoryMatch
@onready var day_label: Label = $HUD/Header/DayLabel
@onready var chat_from: Label = $HUD/Chat/From
@onready var chat_text: Label = $HUD/Chat/Bubble/Text
@onready var memo: SpecMemo = $HUD/SpecMemo
@onready var memo_button: Button = $HUD/Desk/MemoButton
@onready var report_form: ReportForm = $HUD/ReportForm
@onready var report_button: Button = $HUD/Desk/ReportButton
@onready var dev_button: Button = $HUD/Header/DevButton
@onready var dev_panel: Control = $HUD/DevPanel
@onready var switches: HBoxContainer = $HUD/DevPanel/Switches
@onready var restart_button: Button = $HUD/DevPanel/Restart
@onready var dev_judge_label: Label = $HUD/DevPanel/LastJudge


func _ready() -> void:
	day = _load_json(DAY_PATH)
	spec = _load_json(day.spec)
	bugs = _load_json(BUGS_PATH).bugs
	report_options = _load_json(day.report)
	enabled = day.bugs.duplicate()

	day_label.text = "%d日目　朝" % day.day
	chat_from.text = day.chat_from
	chat_text.text = day.chat
	memo_button.pressed.connect(func(): memo.show_spec(spec))
	report_button.pressed.connect(func():
		report_form.open(report_options, "%s %s %s" % [spec.title, spec.event, spec.version]))
	report_form.submitted.connect(_on_report_submitted)
	game.bug_seen.connect(func(id):
		if not observed.has(id):
			observed.append(id))

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


func _on_report_submitted(report: Dictionary) -> void:
	var judge := ReportJudge.judge(report, bugs, enabled, observed, reported)
	_show_dev_judge(judge)
	report_form.visible = false
	if judge.result == ReportJudge.NOT_SEEN:
		# 見ていないバグは提出させない（選んだ内容は残しておく）
		chat_text.text = CHAT_NOT_SEEN
		return
	reports.append({"report": report, "judge": judge})
	if judge.bug_id != "" and not reported.has(judge.bug_id):
		reported.append(judge.bug_id)
	report_form.clear()
	chat_text.text = CHAT_SUBMITTED


# 開発用：直近の判定を DEV パネルに出す（本番では④の「1日の結果」で見せる）
func _show_dev_judge(judge: Dictionary) -> void:
	var text := "直近の判定: %s %s" % [ReportJudge.result_text(judge.result), judge.bug_id]
	if judge.has("checks"):
		var marks := []
		for key in ReportJudge.CHECK_KEYS:
			marks.append("%s%s" % [key, "○" if judge.checks[key] else "×"])
		text += "\n%s 重要度:%s" % [" ".join(marks), judge.severity]
	dev_judge_label.text = text
