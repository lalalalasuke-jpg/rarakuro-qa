class_name DayResult
extends Control

# 1日の結果。報告ごとの開発の返事と正確さ、見逃したバグ、残業したターン数を見せる。

signal retry_pressed
signal next_day_pressed

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.15, 0.14, 0.18)
const ACCENT := Color(0.75, 0.38, 0.08)
const GOOD := Color(0.15, 0.55, 0.3)
const BAD := Color(0.75, 0.2, 0.2)
const CHECK_LABELS := {"where": "どこで", "steps": "手順", "target": "何が", "expected": "期待する動き"}
const SEVERITY_TEXT := {"exact": "○", "near": "△", "off": "×"}

var body: VBoxContainer
var retry_button: Button
var next_button: Button


func _ready() -> void:
	visible = false
	size = Vector2(720, 1280)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = size
	add_child(dim)

	var paper := PanelContainer.new()
	paper.position = Vector2(30, 60)
	paper.size = Vector2(660, 1170)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	paper.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	outer.add_child(buttons)
	retry_button = _make_big_button("もう一度", Color(0.17, 0.22, 0.33))
	retry_button.pressed.connect(func(): retry_pressed.emit())
	buttons.add_child(retry_button)
	next_button = _make_big_button("次の日へ", ACCENT)
	next_button.pressed.connect(func(): next_day_pressed.emit())
	buttons.add_child(next_button)


func _make_big_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(8)
	var dis := st.duplicate()
	dis.bg_color = Color(color, 0.35)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, st)
	b.add_theme_stylebox_override("disabled", dis)
	return b


# day_no: 何日目、reports: [{turn, report, judge}]、bugs: その日のバグデータ、fixed: 直ったバグ ID、
# verified: 修正確認が済んだバグ ID、overtime: 残業ターン数、has_next: 次の日が作ってあるか
func show_result(day_no: int, reports: Array, bugs: Array, fixed: Array, verified: Array, overtime: int, has_next := false) -> void:
	for child in body.get_children():
		child.queue_free()
	retry_button.text = "もう一度%d日目" % day_no
	next_button.text = "%d日目へ" % (day_no + 1) if has_next else "%d日目へ（準備中）" % (day_no + 1)
	next_button.disabled = not has_next

	var total := total_score(reports, overtime)
	var max_total := bugs.size() * 100
	var prev_best := _load_best(day_no)
	if total > prev_best:
		_save_best(day_no, total)
	_label("%d日目の結果" % day_no, 34, INK)
	_label("スコア　%d / %d　ランク %s" % [total, max_total, ReportJudge.rank(total, max_total)], 32, ACCENT)
	_label("ベスト %d%s" % [maxi(total, prev_best), "　（新記録！）" if total > prev_best else ""], 20, Color(INK, 0.7))
	_label("見つけて直ったバグ　%d / %d" % [fixed.size(), bugs.size()], 28, GOOD if fixed.size() == bugs.size() else ACCENT)
	_label("修正確認　%d / %d" % [verified.size(), fixed.size()], 24, GOOD if verified.size() == fixed.size() else ACCENT)
	if overtime == 0:
		_label("定時で完了！", 24, GOOD)
	else:
		_label("残業 %dターン（%d点）" % [overtime, overtime * ReportJudge.OVERTIME_PENALTY], 24, ACCENT)

	_heading("提出した報告")
	if reports.is_empty():
		_label("なし", 22, INK)
	for r in reports:
		var judge: Dictionary = r.judge
		var ok: bool = judge.result == ReportJudge.FIX
		_label("%s：「%s」" % [r.turn, r.report.get("actual", "")], 22, INK)
		_label("　→ 開発の返事：%s（%+d点）" % [ReportJudge.result_text(judge.result), ReportJudge.score(judge)], 22, GOOD if ok else BAD)
		if judge.has("checks"):
			var marks := []
			for key in ReportJudge.CHECK_KEYS:
				marks.append("%s%s" % [CHECK_LABELS[key], "○" if judge.checks[key] else "×"])
			marks.append("重要度%s" % SEVERITY_TEXT[judge.severity])
			_label("　" + "　".join(marks), 18, INK)
		# 直ったバグには開発さんの原因メモ（バグの裏側。詳しくは docs/bug-internals.md）
		if ok:
			_cause_memo(_find_bug(bugs, judge.bug_id))

	var missed := bugs.filter(func(b): return not fixed.has(b.id))
	if not missed.is_empty():
		_heading("見逃したバグ")
		for b in missed:
			_label("・%s（%s）" % [b.title, b.trigger], 20, BAD)
			_cause_memo(b)
	visible = true


func _find_bug(bugs: Array, id: String) -> Dictionary:
	for b in bugs:
		if b.id == id:
			return b
	return {}


# 「原因メモ」を少し目立つ枠で出す
func _cause_memo(bug: Dictionary) -> void:
	if not bug.has("cause"):
		return
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.9, 0.94, 0.98)
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = "開発さんの原因メモ：%s" % bug.cause
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.18, 0.3, 0.45))
	box.add_child(l)
	body.add_child(box)


# 1日のスコア：報告ごとの点数の合計＋残業の減点（0点より下にはしない）
static func total_score(reports: Array, overtime: int) -> int:
	var total := overtime * ReportJudge.OVERTIME_PENALTY
	for r in reports:
		total += ReportJudge.score(r.judge)
	return maxi(total, 0)


# ベストスコアは端末に保存する（Web ではブラウザに保存される。読み書きできなくても遊べる）
func _load_best(day_no: int) -> int:
	var path := "user://best_day%d.json" % day_no
	if not FileAccess.file_exists(path):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(data.get("best", 0)) if data is Dictionary else 0


func _save_best(day_no: int, best: int) -> void:
	var f := FileAccess.open("user://best_day%d.json" % day_no, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best}))


func _heading(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	body.add_child(spacer)
	_label("■ " + text, 24, ACCENT)


func _label(text: String, font_size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	body.add_child(l)
