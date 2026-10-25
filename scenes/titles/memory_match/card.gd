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
# 紅葉狩り（v1.4）の絵柄（symbol_index の順）
const AUTUMN_SYMBOLS := ["momiji", "ichou", "donguri", "kinoko", "kuri", "imo", "dango", "susuki"]

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
## 絵柄のセット: "halloween"（v1.3）／"autumn"（v1.4 紅葉狩り）。
## autumn のときも、style を "halloween" にしたカードはハロウィンの絵で描かれる（バグ MM-AU-08 用）
var style := "halloween"
## 裏面のデザイン（表の絵柄とは別。MM-AU-08 で表だけ差し替え漏れになっても、裏はその版のまま）
var back_style := "halloween"


# 仕様メモの絵柄一覧用：表向きで押せないカードを1枚作る
static func make_icon(index: int, icon_size: float, icon_style := "halloween") -> Control:
	var card: MemoryCard = load("res://scenes/titles/memory_match/card.tscn").instantiate()
	card.custom_minimum_size = Vector2(icon_size, icon_size)
	card.symbol_index = index
	card.style = icon_style
	card.back_style = icon_style
	card.face_up = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


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
	# 紅葉狩りの版は、えんじ色の裏面
	draw_rect(rect, Color(0.45, 0.16, 0.12) if back_style == "autumn" else Color(0.28, 0.16, 0.38), true)
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
	if style == "autumn":
		_draw_autumn(AUTUMN_SYMBOLS[symbol_index], r)
	elif halloween:
		_draw_halloween(HALLOWEEN_SYMBOLS[symbol_index], r)
	else:
		_draw_normal(r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 秋（紅葉狩り）の絵柄
func _draw_autumn(kind: String, r: float) -> void:
	match kind:
		"momiji":  # もみじ：赤い5つのとがった葉
			var red := Color("d63c2f")
			for i in 5:
				var ang := -PI / 2 + (i - 2) * 0.62
				var tip := Vector2(cos(ang), sin(ang)) * r * 0.8
				var side := Vector2(cos(ang + PI / 2), sin(ang + PI / 2)) * r * 0.16
				draw_colored_polygon(PackedVector2Array([Vector2(0, r * 0.1) + side, tip, Vector2(0, r * 0.1) - side]), red)
			draw_circle(Vector2(0, r * 0.05), r * 0.22, red)
			draw_line(Vector2(0, r * 0.2), Vector2(0, r * 0.75), Color("8a2a20"), 4.0)
		"ichou":  # いちょう：黄色い扇
			var yellow := Color("f2c230")
			var pts := PackedVector2Array([Vector2(0, r * 0.35)])
			for i in 13:
				var ang := PI + PI * i / 12.0
				pts.append(Vector2(cos(ang), sin(ang) * 0.85) * r * 0.75)
			draw_colored_polygon(pts, yellow)
			draw_line(Vector2(0, r * 0.35), Vector2(0, r * 0.8), Color("b8901d"), 4.0)
			draw_line(Vector2(0, -r * 0.6), Vector2(0, -r * 0.2), FACE_BG, 4.0)
		"donguri":  # どんぐり：茶色の実＋帽子
			draw_circle(Vector2(0, r * 0.15), r * 0.42, Color("b9783a"))
			draw_rect(Rect2(-r * 0.42, -r * 0.4, r * 0.84, r * 0.3), Color("6b4423"), true)
			draw_line(Vector2(0, -r * 0.4), Vector2(0, -r * 0.6), Color("6b4423"), 5.0)
		"kinoko":  # きのこ：赤いかさに白い点
			draw_rect(Rect2(-r * 0.18, -r * 0.05, r * 0.36, r * 0.6), BONE, true)
			var cap := PackedVector2Array()
			for i in 17:
				var ang := PI + PI * i / 16.0
				cap.append(Vector2(cos(ang) * r * 0.75, sin(ang) * r * 0.6))
			draw_colored_polygon(cap, Color("c0392b"))
			for p in [Vector2(-r * 0.35, -r * 0.2), Vector2(0, -r * 0.4), Vector2(r * 0.35, -r * 0.2)]:
				draw_circle(p, r * 0.1, BONE)
		"kuri":  # くり：三角っぽい茶色の実
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -r * 0.65), Vector2(r * 0.6, r * 0.25), Vector2(r * 0.45, r * 0.5),
				Vector2(-r * 0.45, r * 0.5), Vector2(-r * 0.6, r * 0.25),
			]), Color("7a4a24"))
			draw_rect(Rect2(-r * 0.45, r * 0.25, r * 0.9, r * 0.25), Color("d9b38c"), true)
		"imo":  # さつまいも：紫の細長い実
			draw_set_transform(size * 0.5, -0.5, Vector2.ONE)
			draw_circle(Vector2(-r * 0.3, 0), r * 0.32, Color("8e3a7a"))
			draw_circle(Vector2(r * 0.3, 0), r * 0.32, Color("8e3a7a"))
			draw_rect(Rect2(-r * 0.3, -r * 0.32, r * 0.6, r * 0.64), Color("8e3a7a"), true)
			draw_circle(Vector2(r * 0.62, 0), r * 0.12, Color("f2d27a"))
			draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
		"dango":  # お月見だんご：白い丸が3つ
			for p in [Vector2(-r * 0.3, r * 0.3), Vector2(r * 0.3, r * 0.3), Vector2(0, -r * 0.2)]:
				draw_circle(p, r * 0.3, BONE)
				draw_arc(p, r * 0.3, 0.0, TAU, 32, Color(0.75, 0.72, 0.65), 2.0, true)
		"susuki":  # すすき：細い茎と穂
			for dx in [-0.25, 0.0, 0.25]:
				var x: float = dx * r
				draw_line(Vector2(x, r * 0.75), Vector2(x * 1.6, -r * 0.4), Color("b7a76a"), 3.0)
				draw_circle(Vector2(x * 1.6, -r * 0.5), r * 0.14, Color("e8dcb0"))
				draw_circle(Vector2(x * 1.6, -r * 0.3), r * 0.11, Color("e8dcb0"))


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
