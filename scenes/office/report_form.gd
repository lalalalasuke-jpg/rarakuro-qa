class_name ReportForm
extends Control

# 不具合報告書（選ぶだけ）。1ページに1項目ずつ選んで進み、最後に確認ページで提出する。
# 全部の選択肢が一度に見えると「こういうバグがあるのかも」と推測できてしまうので、1項目ずつにしている。
# 選択肢は「このタイトルのバグ候補（data/bugs.json）の正解すべて」＋ダミー（data/report_*.json の extra）。
# 選んだ内容は閉じても残る（提出が通ったら clear() で消す）。

signal submitted(report: Dictionary)

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.15, 0.14, 0.18)
const ACCENT := Color(0.75, 0.38, 0.08)
const NAVY := Color(0.17, 0.22, 0.33)

var subtitle: Label
var progress: Label
var page_title: Label
var page_hint: Label
var options_box: VBoxContainer
var back_button: Button
var next_button: Button

# [{key, label, hint, options}]
var fields: Array = []
# 項目キー → 選んだ文言
var selections := {}
# 今のページ（fields.size() のときは確認ページ）
var page := 0


func _ready() -> void:
	visible = false
	size = Vector2(720, 1280)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = size
	add_child(dim)  # mouse_filter は STOP のまま＝下のゲームに触れない

	var paper := PanelContainer.new()
	paper.position = Vector2(30, 60)
	paper.size = Vector2(660, 1170)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 26
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	paper.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := _make_label("不具合報告書", 32, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "閉じる ×"
	close.flat = true
	close.add_theme_font_size_override("font_size", 22)
	close.add_theme_color_override("font_color", INK)
	close.add_theme_color_override("font_hover_color", INK)
	close.pressed.connect(func(): visible = false)
	top.add_child(close)

	subtitle = _make_label("", 20, ACCENT)
	outer.add_child(subtitle)
	progress = _make_label("", 20, Color(INK, 0.6))
	outer.add_child(progress)
	page_title = _make_label("", 30, INK)
	outer.add_child(page_title)
	page_hint = _make_label("", 20, Color(INK, 0.7))
	outer.add_child(page_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	options_box = VBoxContainer.new()
	options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_box.add_theme_constant_override("separation", 10)
	scroll.add_child(options_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	outer.add_child(buttons)
	back_button = _make_big_button("← 戻る", Color(0.55, 0.55, 0.6))
	back_button.pressed.connect(func(): _go(page - 1))
	buttons.add_child(back_button)
	next_button = _make_big_button("次へ →", NAVY)
	next_button.pressed.connect(_on_next)
	buttons.add_child(next_button)


# form: report_*.json の中身、bugs: bugs.json の bugs、title_text: 何の報告か
func open(form: Dictionary, bugs: Array, title_text: String) -> void:
	subtitle.text = title_text
	if fields.is_empty():
		fields = build_fields(form, bugs)
	_go(page)
	visible = true


# 選択肢を作る：このタイトルのバグ候補の正解すべて＋ダミーを混ぜてシャッフル
static func build_fields(form: Dictionary, bugs: Array) -> Array:
	var result := []
	for f in form.fields:
		var options: Array = []
		if f.has("fixed_options"):
			options = f.fixed_options.duplicate()
		else:
			for b in bugs:
				if b.title_ver == form.title_ver and not options.has(b.report[f.key]):
					options.append(b.report[f.key])
			for o in f.get("extra", []):
				if not options.has(o):
					options.append(o)
			options.shuffle()
		result.append({"key": f.key, "label": f.label, "hint": f.get("hint", ""), "options": options})
	return result


func clear() -> void:
	selections.clear()
	page = 0


func _go(p: int) -> void:
	page = clampi(p, 0, fields.size())
	for child in options_box.get_children():
		child.queue_free()
	back_button.disabled = page == 0
	if page < fields.size():
		var f: Dictionary = fields[page]
		progress.text = "%d / %d" % [page + 1, fields.size()]
		page_title.text = f.label
		page_hint.text = f.hint
		for o in f.options:
			var b := _make_option_button(o)
			b.button_pressed = selections.get(f.key) == o
			b.pressed.connect(func():
				selections[f.key] = o
				_go(page))
			options_box.add_child(b)
		next_button.text = "次へ →"
		next_button.disabled = not selections.has(f.key)
	else:
		progress.text = "確認"
		page_title.text = "この内容で提出する？"
		page_hint.text = "直したい項目は「戻る」で選び直せるよ"
		for f in fields:
			options_box.add_child(_make_label("■ " + f.label, 20, ACCENT))
			options_box.add_child(_make_label("　" + str(selections.get(f.key, "（未選択）")), 24, INK))
		next_button.text = "提出する"
		next_button.disabled = selections.size() < fields.size()


func _on_next() -> void:
	if page < fields.size():
		_go(page + 1)
	else:
		submitted.emit(selections.duplicate())


func _make_option_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 22)
	var off := StyleBoxFlat.new()
	off.bg_color = Color.WHITE
	off.border_color = Color(0.7, 0.68, 0.64)
	off.set_border_width_all(2)
	off.set_corner_radius_all(8)
	off.content_margin_left = 18
	off.content_margin_right = 18
	var on := off.duplicate()
	on.bg_color = NAVY
	on.border_color = NAVY
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, off)
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, on)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	return b


func _make_big_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 28)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(8)
	var dis := st.duplicate()
	dis.bg_color = Color(color, 0.35)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, st)
	b.add_theme_stylebox_override("disabled", dis)
	return b


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
