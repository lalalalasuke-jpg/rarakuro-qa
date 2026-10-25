class_name ReportForm
extends Control

# 不具合報告書（選ぶだけ）。選択肢は data/report_*.json から組み立てる。
# 全項目を選ぶと「提出」が押せるようになり、submitted で 項目キー→選んだ文言 を渡す。
# 選んだ内容は閉じても残る（提出が通ったら clear() で消す）。

signal submitted(report: Dictionary)

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.15, 0.14, 0.18)
const ACCENT := Color(0.75, 0.38, 0.08)
const NAVY := Color(0.17, 0.22, 0.33)

var subtitle: Label
var fields_box: VBoxContainer
var submit_button: Button
# 項目キー → ButtonGroup
var groups := {}


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
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	paper.add_child(outer)
	outer.add_child(_make_label("不具合報告書", 32, INK))
	subtitle = _make_label("", 20, ACCENT)
	outer.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	fields_box = VBoxContainer.new()
	fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields_box.add_theme_constant_override("separation", 8)
	scroll.add_child(fields_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	outer.add_child(buttons)
	var cancel := _make_big_button("閉じる", Color(0.55, 0.55, 0.6))
	cancel.pressed.connect(func(): visible = false)
	buttons.add_child(cancel)
	submit_button = _make_big_button("提出する", ACCENT)
	submit_button.pressed.connect(_on_submit)
	buttons.add_child(submit_button)


# options: report_*.json の中身、title_text: 何の報告か（例「神経衰弱 ハロウィンイベント v1.3」）
func open(options: Dictionary, title_text: String) -> void:
	subtitle.text = title_text
	if groups.is_empty():
		_build_fields(options.fields)
	_update_submit()
	visible = true


func clear() -> void:
	for group in groups.values():
		var b: BaseButton = group.get_pressed_button()
		if b:
			b.button_pressed = false
	_update_submit()


func _build_fields(fields: Array) -> void:
	for field in fields:
		var heading := _make_label("■ " + field.label, 22, ACCENT)
		fields_box.add_child(heading)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		fields_box.add_child(flow)
		var group := ButtonGroup.new()
		group.allow_unpress = true
		groups[field.key] = group
		for option in field.options:
			var b := _make_option_button(option)
			b.button_group = group
			b.toggled.connect(func(_on): _update_submit())
			flow.add_child(b)


func _selected() -> Dictionary:
	var report := {}
	for key in groups:
		var b: BaseButton = groups[key].get_pressed_button()
		if b:
			report[key] = b.text
	return report


func _update_submit() -> void:
	if submit_button:
		submit_button.disabled = _selected().size() < groups.size() or groups.is_empty()


func _on_submit() -> void:
	submitted.emit(_selected())


func _make_option_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 20)
	var off := StyleBoxFlat.new()
	off.bg_color = Color.WHITE
	off.border_color = Color(0.7, 0.68, 0.64)
	off.set_border_width_all(2)
	off.set_corner_radius_all(8)
	off.content_margin_left = 14
	off.content_margin_right = 14
	off.content_margin_top = 8
	off.content_margin_bottom = 8
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
