class_name DayResult
extends Control

# 1日の結果。報告ごとの開発の返事と正確さ、見逃したバグ、残業したターン数を見せる。

signal retry_pressed

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.15, 0.14, 0.18)
const ACCENT := Color(0.75, 0.38, 0.08)
const GOOD := Color(0.15, 0.55, 0.3)
const BAD := Color(0.75, 0.2, 0.2)
const CHECK_LABELS := {"where": "どこで", "steps": "手順", "target": "何が", "expected": "期待する動き"}
const SEVERITY_TEXT := {"exact": "○", "near": "△", "off": "×"}

var body: VBoxContainer


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

	var retry := Button.new()
	retry.text = "もう一度1日目をやる"
	retry.custom_minimum_size = Vector2(0, 72)
	retry.add_theme_font_size_override("font_size", 28)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.17, 0.22, 0.33)
	st.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed", "focus"]:
		retry.add_theme_stylebox_override(state, st)
	retry.pressed.connect(func(): retry_pressed.emit())
	outer.add_child(retry)


# day_no: 何日目、reports: [{turn, report, judge}]、bugs: その日のバグデータ、fixed: 直ったバグ ID、overtime: 残業ターン数
func show_result(day_no: int, reports: Array, bugs: Array, fixed: Array, overtime: int) -> void:
	for child in body.get_children():
		child.queue_free()

	_label("%d日目の結果" % day_no, 34, INK)
	_label("見つけて直ったバグ　%d / %d" % [fixed.size(), bugs.size()], 28, GOOD if fixed.size() == bugs.size() else ACCENT)
	if overtime == 0:
		_label("定時で完了！", 24, GOOD)
	else:
		_label("残業 %dターン" % overtime, 24, ACCENT)

	_heading("提出した報告")
	if reports.is_empty():
		_label("なし", 22, INK)
	for r in reports:
		var judge: Dictionary = r.judge
		var ok: bool = judge.result == ReportJudge.FIX
		_label("%s：「%s」" % [r.turn, r.report.get("actual", "")], 22, INK)
		_label("　→ 開発の返事：%s" % ReportJudge.result_text(judge.result), 22, GOOD if ok else BAD)
		if judge.has("checks"):
			var marks := []
			for key in ReportJudge.CHECK_KEYS:
				marks.append("%s%s" % [CHECK_LABELS[key], "○" if judge.checks[key] else "×"])
			marks.append("重要度%s" % SEVERITY_TEXT[judge.severity])
			_label("　" + "　".join(marks), 18, INK)

	var missed := bugs.filter(func(b): return not fixed.has(b.id))
	if not missed.is_empty():
		_heading("見逃したバグ")
		for b in missed:
			_label("・%s（%s）" % [b.title, b.trigger], 20, BAD)
	visible = true


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
