extends Node2D

# 1日目の試作：オフィスの画面。
# 上＝ヘッダーとチャット、真ん中＝モニター（作中タイトルが動く）、下＝机（仕様メモ・報告書・異常なし）。
# その日の担当は data/day1.json、仕様メモの中身は data/spec_*.json、バグは data/bugs.json。
# 日本語は fonts/NotoSansJP-Subset.ttf（project.godot でテーマの標準フォントに設定）で表示できる。
#
# 1日の流れ：朝・昼・夕の3ターン。1ターン＝テストして報告を1つ出す（または「異常なし」）まで。
# 出した報告の返事は次のターンの始めに開発さんから届き、「修正します」のバグはそのターンから直っている。
# 夕方までに全部直らなければ残業ターンが続く（残業中は「今日はあがる」で切り上げられる）。

const BUGS_PATH := "res://data/bugs.json"
const DAY_PATH := "res://data/day1.json"
const TURNS := ["朝", "昼", "夕"]

const CHAT_NOT_SEEN := "その現象、このターンではまだ画面で確認できてないみたい。実際に起きるのを見てから報告してね。"
const LEADER := {"name": "リーダー", "initial": "リ", "color": Color(0.35, 0.55, 0.85)}
const DEV := {"name": "開発さん", "initial": "開", "color": Color(0.3, 0.65, 0.45)}

var day: Dictionary
var spec: Dictionary
var bugs: Array = []
# その日に仕込まれているバグのデータ
var day_bugs: Array = []
var report_options: Dictionary
# 今仕込まれている（まだ直っていない）バグの ID
var enabled: Array = []
# 直ったバグの ID
var fixed: Array = []
# このターンにプレイヤーが画面で見たバグの ID
var observed: Array = []
# 提出した報告 [{turn, report, judge}]
var reports: Array = []
# 返事待ちの報告（次のターンの始めに返事が届く）
var pending: Dictionary = {}
# 0=朝 1=昼 2=夕 3以上=残業
var turn := 0

@onready var game: MemoryMatch = $HUD/Monitor/MemoryMatch
@onready var day_label: Label = $HUD/Header/DayLabel
@onready var avatar: Panel = $HUD/Chat/Avatar
@onready var avatar_initial: Label = $HUD/Chat/Avatar/Initial
@onready var chat_from: Label = $HUD/Chat/From
@onready var chat_text: Label = $HUD/Chat/Bubble/Text
@onready var memo: SpecMemo = $HUD/SpecMemo
@onready var memo_button: Button = $HUD/Desk/MemoButton
@onready var report_form: ReportForm = $HUD/ReportForm
@onready var report_button: Button = $HUD/Desk/ReportButton
@onready var no_bug_button: Button = $HUD/Desk/NoBugButton
@onready var day_result: DayResult = $HUD/DayResult
@onready var dev_button: Button = $HUD/Header/DevButton
@onready var dev_panel: Control = $HUD/DevPanel
@onready var switches: HBoxContainer = $HUD/DevPanel/Switches
@onready var restart_button: Button = $HUD/DevPanel/Restart
@onready var dev_judge_label: Label = $HUD/DevPanel/LastJudge


func _ready() -> void:
	day = _load_json(DAY_PATH)
	spec = _load_json(day.spec)
	bugs = _load_json(BUGS_PATH).bugs
	day_bugs = bugs.filter(func(b): return day.bugs.has(b.id))
	report_options = _load_json(day.report)
	enabled = day.bugs.duplicate()

	memo_button.pressed.connect(func(): memo.show_spec(spec))
	report_button.pressed.connect(func():
		report_form.open(report_options, "%s %s %s" % [spec.title, spec.event, spec.version]))
	report_form.submitted.connect(_on_report_submitted)
	no_bug_button.pressed.connect(_on_no_bug_pressed)
	day_result.retry_pressed.connect(func(): get_tree().reload_current_scene())
	game.bug_seen.connect(func(id):
		if not observed.has(id):
			observed.append(id))

	_build_dev_switches()
	dev_button.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)
	restart_button.pressed.connect(_restart)
	_start_turn()


func _load_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("%s が読めない" % path)
		return {}
	return data


func _turn_name() -> String:
	return TURNS[turn] if turn < TURNS.size() else "残業%d" % (turn - TURNS.size() + 1)


func _is_overtime() -> bool:
	return turn >= TURNS.size()


# ターンの始め：表示を更新し、返事が届いていればチャットに出して、作中タイトルを最初から始める
func _start_turn() -> void:
	observed.clear()
	day_label.text = "%d日目　%s" % [day.day, _turn_name()]
	no_bug_button.text = "今日はあがる" if _is_overtime() else "異常なし"
	if not pending.is_empty():
		_say(DEV, ReportJudge.dev_reply(pending.report, pending.judge))
		pending = {}
	elif turn == 0:
		_say(LEADER, day.chat)
	else:
		_say(LEADER, day.turn_chats["残業" if _is_overtime() else TURNS[turn]])
	_restart()


# ターンの終わり：返事待ちの報告が「修正します」なら直す → 全部直ったら1日の終わり、まだなら次のターンへ
func _end_turn() -> void:
	if not pending.is_empty() and pending.judge.result == ReportJudge.FIX:
		enabled.erase(pending.judge.bug_id)
		fixed.append(pending.judge.bug_id)
		_sync_dev_switches()
	if day_bugs.all(func(b): return fixed.has(b.id)):
		_finish_day()
		return
	turn += 1
	_start_turn()


func _finish_day() -> void:
	day_result.show_result(day.day, reports, day_bugs, fixed, maxi(0, turn - TURNS.size() + 1))


func _on_report_submitted(report: Dictionary) -> void:
	var judge := ReportJudge.judge(report, bugs, enabled, observed, fixed)
	_show_dev_judge(judge)
	report_form.visible = false
	if judge.result == ReportJudge.NOT_SEEN:
		# 見ていないバグは提出させない（選んだ内容は残しておく）
		_say(LEADER, CHAT_NOT_SEEN)
		return
	pending = {"turn": _turn_name(), "report": report, "judge": judge}
	reports.append(pending)
	report_form.clear()
	_end_turn()


func _on_no_bug_pressed() -> void:
	if _is_overtime():
		_finish_day()
		return
	pending = {}
	_end_turn()


func _say(who: Dictionary, text: String) -> void:
	avatar_initial.text = who.initial
	var style: StyleBoxFlat = avatar.get_theme_stylebox("panel").duplicate()
	style.bg_color = who.color
	avatar.add_theme_stylebox_override("panel", style)
	chat_from.text = who.name
	chat_text.text = text


func _restart() -> void:
	game.start(enabled)


# 開発用：バグを1つずつ ON/OFF してプレイし直せるスイッチ（本番では隠す）
func _build_dev_switches() -> void:
	for bug in bugs:
		var id: String = bug.id
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(200, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.set_meta("bug_id", id)
		b.toggled.connect(_on_switch_toggled.bind(id, b))
		switches.add_child(b)
	_sync_dev_switches()


func _sync_dev_switches() -> void:
	for b in switches.get_children():
		var id: String = b.get_meta("bug_id")
		b.set_pressed_no_signal(enabled.has(id))
		_update_switch_text(b, id, enabled.has(id))


func _on_switch_toggled(on: bool, id: String, b: Button) -> void:
	if on and not enabled.has(id):
		enabled.append(id)
	elif not on:
		enabled.erase(id)
	_update_switch_text(b, id, on)
	_restart()


func _update_switch_text(b: Button, id: String, on: bool) -> void:
	b.text = "%s %s" % [id.trim_prefix("MM-HW-"), "ON" if on else "OFF"]


# 開発用：直近の判定を DEV パネルに出す
func _show_dev_judge(judge: Dictionary) -> void:
	var text := "直近の判定: %s %s" % [ReportJudge.result_text(judge.result), judge.bug_id]
	if judge.has("checks"):
		var marks := []
		for key in ReportJudge.CHECK_KEYS:
			marks.append("%s%s" % [key, "○" if judge.checks[key] else "×"])
		text += "\n%s 重要度:%s" % [" ".join(marks), judge.severity]
	dev_judge_label.text = text
