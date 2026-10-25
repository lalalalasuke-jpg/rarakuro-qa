class_name SuikaFruitIcon
extends Control

# 果物を1つ描くだけの小さな部品（NEXT 表示と仕様メモの果物一覧で使う）

var rank := 0


static func make_icon(index: int, icon_size: float) -> Control:
	var icon := SuikaFruitIcon.new()
	icon.rank = index
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func show_rank(r: int) -> void:
	rank = r
	queue_redraw()


func _draw() -> void:
	# 大きい果物も枠に収まるように、ランクで少しずつ大きく（最大は枠いっぱい）
	var max_r := minf(size.x, size.y) * 0.5 - 2.0
	var r := lerpf(max_r * 0.45, max_r, float(rank) / SuikaFruit.MAX_RANK)
	SuikaFruit.paint_face(self, r, rank, size * 0.5)
