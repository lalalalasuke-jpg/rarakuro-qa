class_name MemoryCard
extends Button

# 作中タイトル「神経衰弱」のカード。画像を使わず _draw() で描く。
# ハロウィン版（v1.3）は8種類の図形、通常版は元の memory-match と同じ「色つき丸＋文字」。

# 通常の絵柄（元の memory-match と同じ）
const NORMAL_SYMBOLS := [
	{"letter": "A", "color": Color("e74c3c")},
	{"letter": "B", "color": Color("e67e22")},
	{"letter": "C", "color": Color("f1c40f")},
	{"letter": "D", "color": Color("27ae60")},
	{"letter": "E", "color": Color("16a085")},
	{"letter": "F", "color": Color("2980b9")},
	{"letter": "G", "color": Color("9b59b6")},
	{"letter": "H", "color": Color("e84393")},
]

# ハロウィンの絵柄（symbol_index の順）
const HALLOWEEN_SYMBOLS := ["pumpkin", "ghost", "bat", "moon", "hat", "candy", "skull", "cat"]

const FACE_BG := Color(0.16, 0.13, 0.2)
const ORANGE := Color("f28c28")
const PURPLE := Color("8e44ad")
const BONE := Color("f4f1e8")
const INK := Color(0.08, 0.07, 0.1)

var symbol_index := 0
var face_up := false
var matched := false
# false のカードは通常の絵柄で描く（バグ MM-HW-001 用）
var halloween := true


func flip_up() -> void:
	face_up = true
	queue_redraw()


func flip_down() -> void:
	face_up = false
	queue_redraw()


# ペア成立：これ以降は押せなくして、少し薄くする
func set_matched() -> void:
	matched = true
	disabled = true
	modulate = Color(1, 1, 1, 0.5)


func _draw() -> void:
	if face_up or matched:
		_draw_face()
	else:
		_draw_back()


# 裏向き：ハロウィンらしい紫の裏面にかぼちゃ色のひし形
func _draw_back() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.28, 0.16, 0.38), true)
	draw_rect(rect, ORANGE, false, 4.0)
	var c := size * 0.5
	var half := Vector2(size.x * 0.22, size.y * 0.22)
	var diamond := PackedVector2Array([
		c + Vector2(0, -half.y), c + Vector2(half.x, 0),
		c + Vector2(0, half.y), c + Vector2(-half.x, 0),
	])
	draw_colored_polygon(diamond, Color(ORANGE, 0.55))


func _draw_face() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FACE_BG, true)
	# 以降は中心を原点、半径 r を基準にして描く
	var r := minf(size.x, size.y) * 0.5 - 10.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
	if halloween:
		_draw_halloween(HALLOWEEN_SYMBOLS[symbol_index], r)
	else:
		_draw_normal(r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 通常の絵柄：元の memory-match と同じ「色つき丸＋文字」
func _draw_normal(r: float) -> void:
	var sym: Dictionary = NORMAL_SYMBOLS[symbol_index]
	draw_circle(Vector2.ZERO, r, Color(0.16, 0.16, 0.2))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, sym.color, 3.0, true)
	var font := ThemeDB.fallback_font
	var font_size := 44
	var text: String = sym.letter
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(-text_size.x * 0.5, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, sym.color)


func _draw_halloween(kind: String, r: float) -> void:
	match kind:
		"pumpkin":
			draw_rect(Rect2(-r * 0.08, -r * 0.8, r * 0.16, r * 0.3), Color("2e8b57"), true)
			draw_circle(Vector2(-r * 0.32, 0.05 * r), r * 0.5, Color("d9731a"))
			draw_circle(Vector2(r * 0.32, 0.05 * r), r * 0.5, Color("d9731a"))
			draw_circle(Vector2(0, 0.05 * r), r * 0.55, ORANGE)
			_tri(Vector2(-r * 0.3, -r * 0.15), r * 0.13, INK, true)
			_tri(Vector2(r * 0.3, -r * 0.15), r * 0.13, INK, true)
			draw_rect(Rect2(-r * 0.3, r * 0.2, r * 0.6, r * 0.12), INK, true)
		"ghost":
			draw_circle(Vector2(0, -r * 0.2), r * 0.5, BONE)
			draw_rect(Rect2(-r * 0.5, -r * 0.2, r * 1.0, r * 0.7), BONE, true)
			for i in 3:
				draw_circle(Vector2(-r * 0.33 + r * 0.33 * i, r * 0.5), r * 0.17, BONE)
			draw_circle(Vector2(-r * 0.18, -r * 0.25), r * 0.09, INK)
			draw_circle(Vector2(r * 0.18, -r * 0.25), r * 0.09, INK)
		"bat":
			var bat := Color("5b4a7a")
			var wing_l := PackedVector2Array([
				Vector2(-r * 0.15, -r * 0.1), Vector2(-r * 0.9, -r * 0.35),
				Vector2(-r * 0.7, 0), Vector2(-r * 0.5, r * 0.25), Vector2(-r * 0.15, r * 0.15),
			])
			var wing_r := PackedVector2Array()
			for p in wing_l:
				wing_r.append(Vector2(-p.x, p.y))
			draw_colored_polygon(wing_l, bat)
			draw_colored_polygon(wing_r, bat)
			draw_circle(Vector2.ZERO, r * 0.25, bat)
			_tri(Vector2(-r * 0.13, -r * 0.3), r * 0.1, bat, true)
			_tri(Vector2(r * 0.13, -r * 0.3), r * 0.1, bat, true)
			draw_circle(Vector2(-r * 0.09, -r * 0.03), r * 0.05, Color("f1c40f"))
			draw_circle(Vector2(r * 0.09, -r * 0.03), r * 0.05, Color("f1c40f"))
		"moon":
			draw_circle(Vector2(-r * 0.1, 0), r * 0.62, Color("f7dc6f"))
			draw_circle(Vector2(r * 0.18, -r * 0.15), r * 0.55, FACE_BG)
		"hat":
			draw_rect(Rect2(-r * 0.75, r * 0.3, r * 1.5, r * 0.18), PURPLE, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 0.45, r * 0.32), Vector2(r * 0.45, r * 0.32), Vector2(r * 0.1, -r * 0.8),
			]), PURPLE)
			draw_rect(Rect2(-r * 0.4, r * 0.12, r * 0.78, r * 0.14), ORANGE, true)
		"candy":
			var pink := Color("ff6fae")
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 0.3, 0), Vector2(-r * 0.8, -r * 0.3), Vector2(-r * 0.8, r * 0.3),
			]), pink)
			draw_colored_polygon(PackedVector2Array([
				Vector2(r * 0.3, 0), Vector2(r * 0.8, -r * 0.3), Vector2(r * 0.8, r * 0.3),
			]), pink)
			draw_circle(Vector2.ZERO, r * 0.38, pink)
			draw_arc(Vector2.ZERO, r * 0.22, 0.0, PI * 1.5, 24, BONE, 4.0, true)
		"skull":
			draw_circle(Vector2(0, -r * 0.12), r * 0.52, BONE)
			draw_rect(Rect2(-r * 0.28, r * 0.25, r * 0.56, r * 0.3), BONE, true)
			draw_circle(Vector2(-r * 0.2, -r * 0.12), r * 0.14, INK)
			draw_circle(Vector2(r * 0.2, -r * 0.12), r * 0.14, INK)
			_tri(Vector2(0, r * 0.12), r * 0.07, INK)
			for i in 3:
				draw_line(Vector2(-r * 0.14 + r * 0.14 * i, r * 0.32), Vector2(-r * 0.14 + r * 0.14 * i, r * 0.55), INK, 3.0)
		"cat":
			var fur := Color(0.05, 0.05, 0.07)
			draw_circle(Vector2(0, r * 0.08), r * 0.55, Color(0.45, 0.4, 0.55))
			draw_circle(Vector2(0, r * 0.08), r * 0.5, fur)
			_tri(Vector2(-r * 0.32, -r * 0.42), r * 0.22, fur, true)
			_tri(Vector2(r * 0.32, -r * 0.42), r * 0.22, fur, true)
			draw_circle(Vector2(-r * 0.2, 0), r * 0.1, Color("b7e04a"))
			draw_circle(Vector2(r * 0.2, 0), r * 0.1, Color("b7e04a"))
			draw_circle(Vector2(-r * 0.2, 0), r * 0.04, fur)
			draw_circle(Vector2(r * 0.2, 0), r * 0.04, fur)


# 中心 c・大きさ s の三角形（up=true で上向き、false で下向き）
func _tri(c: Vector2, s: float, color: Color, up := false) -> void:
	var tip := -s if up else s
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s, -tip * 0.6), c + Vector2(s, -tip * 0.6), c + Vector2(0, tip),
	]), color)
