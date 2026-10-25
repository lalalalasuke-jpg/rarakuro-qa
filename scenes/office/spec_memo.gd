class_name SpecMemo
extends Control

# 仕様メモ（紙の資料ふう）。中身は仕様データ（data/spec_*.json）から組み立てる。
# 全画面を覆い、下のゲームは押せなくなる。「閉じる」で消える。

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.15, 0.14, 0.18)
const ACCENT := Color(0.75, 0.38, 0.08)

var body: VBoxContainer
var scroll: ScrollContainer


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
	outer.add_theme_constant_override("separation", 12)
	paper.add_child(outer)
	# 長い仕様メモはスクロールして読む（「閉じる」は常に下に見えている）
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

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
	scroll.scroll_vertical = 0
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
	_heading(spec.get("rewards_heading", "報酬"))
	for r in spec.rewards:
		_label("・" + r, 24, INK)
	# アップデートの版には「リリースノート（この版で直したこと・変えたこと）」が付く
	if spec.has("release_notes"):
		_heading(spec.get("release_notes_heading", "リリースノート"))
		for r in spec.release_notes:
			_label("・" + r, 22, INK)
	_heading(spec.get("symbols_heading", "絵柄"))
	_label(spec.symbols_note, 22, INK)

	# 絵柄の一覧。絵は作中タイトルのスクリプトの make_icon(番号, 大きさ) で描く
	var icon_script: Script = load(spec.icon_script)
	var columns: int = spec.get("icon_columns", 4)
	var icon_size: float = spec.get("icon_size", 124)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for i in spec.symbols.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(icon_script.make_icon(i, icon_size))
		var name_label := _make_label(spec.symbols[i], 18 if columns > 4 else 20, INK)
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
