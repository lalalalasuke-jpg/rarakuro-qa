class_name SpecMemo
extends Control

# 仕様メモ（紙の資料ふう）。中身は仕様データ（data/spec_*.json）から組み立てる。
# 全画面を覆い、下のゲームは押せなくなる。「閉じる」で消える。

const CARD := preload("res://scenes/titles/memory_match/card.tscn")
const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.15, 0.14, 0.18)
const ACCENT := Color(0.75, 0.38, 0.08)

var body: VBoxContainer


func _ready() -> void:
	visible = false
	size = Vector2(720, 1280)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = size
	add_child(dim)  # mouse_filter は STOP のまま＝下のゲームに触れない

	var paper := PanelContainer.new()
	paper.position = Vector2(40, 70)
	paper.size = Vector2(640, 1140)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(6)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)

	var outer := VBoxContainer.new()
	paper.add_child(outer)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)

	var close := Button.new()
	close.text = "閉じる"
	close.custom_minimum_size = Vector2(0, 72)
	close.add_theme_font_size_override("font_size", 28)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.17, 0.22, 0.33)
	close_style.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(state, close_style)
	close.pressed.connect(func(): visible = false)
	outer.add_child(close)


func show_spec(spec: Dictionary) -> void:
	for child in body.get_children():
		child.queue_free()

	_label("イベント仕様メモ", 22, ACCENT)
	_label("%s %s %s" % [spec.title, spec.event, spec.version], 32, INK)
	_line()
	_heading("期間")
	_label(spec.period, 24, INK)
	_heading("ルール")
	for r in spec.rules:
		_label("・" + r, 24, INK)
	_heading("報酬")
	for r in spec.rewards:
		_label("・" + r, 24, INK)
	_heading("絵柄")
	_label(spec.symbols_note, 22, INK)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for i in spec.symbols.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var card: MemoryCard = CARD.instantiate()
		card.custom_minimum_size = Vector2(124, 124)
		card.symbol_index = i
		card.face_up = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(card)
		var name_label := _make_label(spec.symbols[i], 20, INK)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		grid.add_child(cell)
	visible = true


func _heading(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	body.add_child(spacer)
	_label("■ " + text, 24, ACCENT)


func _line() -> void:
	var line := ColorRect.new()
	line.color = Color(INK, 0.3)
	line.custom_minimum_size = Vector2(0, 2)
	body.add_child(line)


func _label(text: String, font_size: int, color: Color) -> void:
	body.add_child(_make_label(text, font_size, color))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
