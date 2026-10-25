class_name OfficeMain
extends Node2D

# オフィスの画面（1日ぶん）。
# 上＝ヘッダーとチャット、真ん中＝モニター（その日の作中タイトルが動く）、下＝机（仕様メモ・報告書・異常なし）。
# その日の担当は data/dayN.json（作中タイトルのシーン・仕様メモ・報告書・バグ候補）、バグは data/bugs.json。
# 作中タイトルは start(enabled_bugs) と bug_checked(id, occurred) シグナルを持っていればどれでもはめ込める。
# 日本語は fonts/NotoSansJP-Subset.ttf（project.godot でテーマの標準フォントに設定）で表示できる。
#
# 1日の流れ：朝・昼・夕の3ターン。1ターン＝テストして報告を1つ出す（または「異常なし」）まで。
# 出した報告の返事は次のターンの始めに開発さんから届き、「修正します」のバグはそのターンから直っている。
# 直ったバグは、まず同じ操作をしてバグが出ないことを確かめる（修正確認）。確認が終わるまで次の報告は出せない。
# 夕方までに全部直らなければ残業ターンが続く（残業中は「今日はあがる」で切り上げられる）。
# 最後の修正が届いたら「終業前」ターンで修正確認をして、1日の結果へ。

const BUGS_PATH := "res://data/bugs.json"
const DAY_PATH := "res://data/day%d.json"
## 作ってある最後の日
const LAST_DAY := 3
## どこまで進んだかの保存先（次に開いたときはこの日から）
const PROGRESS_PATH := "user://progress.json"
const TURNS := ["朝", "昼", "夕"]
## モニターの中に作中タイトルを置く位置と大きさ
const SCREEN_POS := Vector2(20, 20)
const SCREEN_SCALE := 0.8

## 次に読み込む日（「次の日へ」や DEV の日選びで決める。0 なら保存された日）
static var next_day := 0
## 開発さんの返事のあと、リーダーが話し出すまでの間（秒）
const LEADER_DELAY := 1.8

const CHAT_NOT_SEEN := "その現象、このターンではまだ画面で確認できてないみたい。実際に起きるのを見てから報告してね。"
const CHAT_VERIFY := "まずは直ってるか確認しよっか。「%s」をやってみて、バグが出ないか見てみてね。"
const CHAT_VERIFIED := "ちゃんと直ってるね！じゃあ、ほかに不具合がないか探してみよう。"
const CHAT_VERIFIED_LAST := "全部直ってるね！今日はこれで終わり、おつかれさま。"
const LEADER := {"name": "リーダー", "initial": "リ", "color": Color(0.35, 0.55, 0.85)}
const DEV := {"name": "開発さん", "initial": "開", "color": Color(0.3, 0.65, 0.45)}

var day_no := 1
var day: Dictionary
var spec: Dictionary
# その日のタイトルのバグ候補（data/bugs.json のうち day.bug_pool にあるもの）
var bugs: Array = []
# その日に仕込まれているバグのデータ
var day_bugs: Array = []
var report_form_data: Dictionary
# 今仕込まれている（まだ直っていない）バグの ID
var enabled: Array = []
# 直ったバグの ID
var fixed: Array = []
# 修正確認待ちのバグの ID と、確認が済んだバグの ID
var verifying: Array = []
var verified: Array = []
# このターンにプレイヤーが画面で見たバグの ID
var observed: Array = []
# 提出した報告 [{turn, report, judge}]
var reports: Array = []
# 返事待ちの報告（次のターンの始めに返事が届く）
var pending: Dictionary = {}
# 0=朝 1=昼 2=夕 3以上=残業
var turn := 0
# 「終業前」ターン（最後の修正確認）中か
var closing := false
# 遅れて出すチャットが古くなっていないかの見分け用
var chat_serial := 0

# その日の作中タイトル（data/dayN.json の title_scene から作る）
var game: Control
@onready var monitor: Control = $HUD/Monitor
@onready var dev_days: HBoxContainer = $HUD/DevPanel/Days
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
@onready var reboot_button: Button = $HUD/RebootButton
@onready var day_result: DayResult = $HUD/DayResult
@onready var dev_button: Button = $HUD/Header/DevButton
@onready var dev_panel: Control = $HUD/DevPanel
@onready var switches: HFlowContainer = $HUD/DevPanel/Switches
@onready var restart_button: Button = $HUD/DevPanel/Restart
@onready var dev_judge_label: Label = $HUD/DevPanel/LastJudge
var toast: PanelContainer


func _ready() -> void:
	day_no = next_day if next_day > 0 else load_progress()
	next_day = 0
	day = _load_json(DAY_PATH % day_no)
	spec = _load_json(day.spec)
	bugs = _load_json(BUGS_PATH).bugs.filter(func(b): return day.bug_pool.has(b.id))
	report_form_data = _load_json(day.report)

	game = load(day.title_scene).instantiate()
	if day.has("title_options") and game.has_method("configure"):
		game.configure(day.title_options)
	game.position = SCREEN_POS
	game.scale = Vector2(SCREEN_SCALE, SCREEN_SCALE)
	monitor.add_child(game)
	game.bug_checked.connect(_on_bug_checked)
	# その日のバグは候補の中から毎回ランダムに選ぶ（遊ぶたびに違うバグが出る）
	setup_bugs(pick_bugs(bugs, day.pick))

	memo_button.pressed.connect(func(): memo.show_spec(spec))
	report_button.pressed.connect(func():
		report_form.open(report_form_data, bugs, "%s %s %s" % [spec.title, spec.event, spec.version]))
	report_form.submitted.connect(_on_report_submitted)
	no_bug_button.pressed.connect(_on_no_bug_pressed)
	reboot_button.pressed.connect(_restart)
	day_result.retry_pressed.connect(func(): go_to_day(day_no))
	day_result.next_day_pressed.connect(func(): go_to_day(day_no + 1))
	_style_desk_disabled()
	_build_toast()

	_build_dev_switches()
	dev_button.pressed.connect(func(): dev_panel.visible = not dev_panel.visible)
	restart_button.pressed.connect(_restart)
	_start_turn()


# 候補からランダムに count 個選ぶ。同じ group のバグ（同じ場所のバグ）は同じ日に重ならない
static func pick_bugs(candidates: Array, count: int) -> Array:
	var pool := candidates.duplicate()
	pool.shuffle()
	var picked: Array = []
	var groups: Array = []
	for b in pool:
		if picked.size() >= count:
			break
		var g: String = b.get("group", "")
		if g != "" and groups.has(g):
			continue
		picked.append(b.id)
		if g != "":
			groups.append(g)
	return picked


# 別の日を読み込み直す（進んだ日は保存して、次に開いたときもその日から）
func go_to_day(n: int) -> void:
	n = clampi(n, 1, LAST_DAY)
	save_progress(n)
	next_day = n
	get_tree().reload_current_scene()


static func load_progress() -> int:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return 1
	var data = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_PATH))
	return clampi(int(data.get("day", 1)), 1, LAST_DAY) if data is Dictionary else 1


static func save_progress(n: int) -> void:
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"day": n}))


func _load_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("%s が読めない" % path)
		return {}
	return data


# その日に仕込むバグを決める（テストからも呼んで固定できる）
func setup_bugs(ids: Array) -> void:
	enabled = ids.duplicate()
	day_bugs = bugs.filter(func(b): return ids.has(b.id))
	if switches.get_child_count() > 0:
		_sync_dev_switches()
		_restart()


func _bug(id: String) -> Dictionary:
	for b in bugs:
		if b.id == id:
			return b
	return {}


func _turn_name() -> String:
	if closing:
		return "終業前"
	return TURNS[turn] if turn < TURNS.size() else "残業%d" % (turn - TURNS.size() + 1)


func _is_overtime() -> bool:
	return turn >= TURNS.size()


# ターンの始め：表示を更新し、返事が届いていればチャットに出して、作中タイトルを最初から始める
func _start_turn() -> void:
	observed.clear()
	day_label.text = "%d日目　%s" % [day.day, _turn_name()]
	if not pending.is_empty():
		_say(DEV, ReportJudge.dev_reply(pending.report, pending.judge))
		if pending.judge.result == ReportJudge.FIX:
			verifying.append(pending.judge.bug_id)
			_say_later(LEADER, CHAT_VERIFY % _bug(pending.judge.bug_id).report.steps)
		pending = {}
	elif turn == 0:
		_say(LEADER, day.chat)
	else:
		_say(LEADER, day.turn_chats["残業" if _is_overtime() else TURNS[turn]])
	_update_desk()
	_restart()


# ターンの終わり：返事待ちの報告が「修正します」なら直す → 全部直ったら終業前、まだなら次のターンへ
func _end_turn() -> void:
	if not pending.is_empty() and pending.judge.result == ReportJudge.FIX:
		enabled.erase(pending.judge.bug_id)
		fixed.append(pending.judge.bug_id)
		_sync_dev_switches()
	if day_bugs.all(func(b): return fixed.has(b.id)):
		closing = true
	else:
		turn += 1
	_start_turn()


func _finish_day() -> void:
	var overtime := maxi(0, turn - TURNS.size() + 1)
	day_result.show_result(day_no, reports, day_bugs, fixed, verified, overtime, day_no < LAST_DAY)


# 修正確認中・終業前は報告書と異常なしを押せない
func _update_desk() -> void:
	var locked := not verifying.is_empty() or closing
	report_button.disabled = locked
	no_bug_button.disabled = locked
	no_bug_button.text = "今日はあがる" if _is_overtime() else "異常なし"


func _on_bug_checked(id: String, occurred: bool) -> void:
	if occurred:
		if not observed.has(id):
			observed.append(id)
	elif verifying.has(id):
		verifying.erase(id)
		verified.append(id)
		_on_fix_verified()


func _on_fix_verified() -> void:
	_show_toast("修正確認完了！")
	if not verifying.is_empty():
		return
	if closing:
		_say(LEADER, CHAT_VERIFIED_LAST)
		await get_tree().create_timer(LEADER_DELAY).timeout
		_finish_day()
	else:
		_say(LEADER, CHAT_VERIFIED)
		_update_desk()


func _on_report_submitted(report: Dictionary) -> void:
	if closing or not verifying.is_empty():
		return  # 修正確認中・終業前は報告できない（ボタンも押せないが念のため）
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
	chat_serial += 1
	avatar_initial.text = who.initial
	var style: StyleBoxFlat = avatar.get_theme_stylebox("panel").duplicate()
	style.bg_color = who.color
	avatar.add_theme_stylebox_override("panel", style)
	chat_from.text = who.name
	chat_text.text = text


# 少し間をあけてから話す（その間に別のメッセージが出ていたら出さない）
func _say_later(who: Dictionary, text: String) -> void:
	var serial := chat_serial
	await get_tree().create_timer(LEADER_DELAY).timeout
	if serial == chat_serial:
		_say(who, text)


func _style_desk_disabled() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.8, 0.76, 0.7)
	st.set_corner_radius_all(10)
	for b in [report_button, no_bug_button]:
		b.add_theme_stylebox_override("disabled", st)
		b.add_theme_color_override("font_disabled_color", Color(0.5, 0.47, 0.44))


# モニターの上にぽんっと出る通知
func _build_toast() -> void:
	toast = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.15, 0.55, 0.3)
	st.set_corner_radius_all(14)
	st.content_margin_left = 36
	st.content_margin_right = 36
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	toast.add_theme_stylebox_override("panel", st)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 40)
	toast.add_child(l)
	toast.visible = false
	$HUD.add_child(toast)


func _show_toast(text: String) -> void:
	var l: Label = toast.get_child(0)
	l.text = text
	toast.reset_size()
	toast.position = monitor.position + (monitor.size - toast.size) * 0.5
	toast.modulate.a = 1.0
	toast.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): toast.visible = false)


func _restart() -> void:
	game.start(enabled)


# 開発用：バグを1つずつ ON/OFF してプレイし直せるスイッチ（本番では隠す）
func _build_dev_switches() -> void:
	for bug in bugs:
		var id: String = bug.id
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.set_meta("bug_id", id)
		b.toggled.connect(_on_switch_toggled.bind(id, b))
		switches.add_child(b)
	_sync_dev_switches()
	# 日を選ぶボタン（その日の最初から）
	for n in range(1, LAST_DAY + 1):
		var d := Button.new()
		d.text = "%d日目" % n
		d.custom_minimum_size = Vector2(120, 48)
		d.add_theme_font_size_override("font_size", 20)
		d.disabled = n == day_no
		d.pressed.connect(go_to_day.bind(n))
		dev_days.add_child(d)


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
	b.text = "%s %s" % [id.get_slice("-", id.get_slice_count("-") - 1), "ON" if on else "OFF"]


# 開発用：直近の判定を DEV パネルに出す
func _show_dev_judge(judge: Dictionary) -> void:
	var text := "直近の判定: %s %s" % [ReportJudge.result_text(judge.result), judge.bug_id]
	if judge.has("checks"):
		var marks := []
		for key in ReportJudge.CHECK_KEYS:
			marks.append("%s%s" % [key, "○" if judge.checks[key] else "×"])
		text += "\n%s 重要度:%s" % [" ".join(marks), judge.severity]
	dev_judge_label.text = text
