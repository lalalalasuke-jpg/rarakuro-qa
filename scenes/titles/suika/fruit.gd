class_name SuikaFruit
extends RigidBody2D

# 作中タイトル「スイカゲーム」の果物。元の suika-game の Fruit を流用（モニターに収まるよう少し小さく）。
# 何かにぶつかったら contact で作中タイトル（SuikaTitle）に知らせ、合体などの判断はそちらでする。

signal contact(me: SuikaFruit, other: Node)

## ランクごとの半径（ピクセル）。index がそのまま rank
const RADII := [21.0, 27.0, 35.0, 45.0, 56.0, 67.0, 80.0, 94.0, 110.0, 128.0, 148.0]
const COLORS: Array[Color] = [
	Color("e74c3c"), Color("e67e22"), Color("9b59b6"), Color("f1c40f"),
	Color("e84393"), Color("c0392b"), Color("16a085"), Color("2980b9"),
	Color("27ae60"), Color("d35400"), Color("2ecc71"),
]
## 一番上のランク（これ以上は合体しない）
const MAX_RANK := 10

var rank := 0
var radius: float = RADII[0]
## 合体で消費済み。二重合体を防ぐ
var merged := false
## 見た目だけの拡大率。合体演出で一瞬大きくする
var draw_scale := 1.0


func _ready() -> void:
	_apply_rank()
	body_entered.connect(func(body): contact.emit(self, body))


func _apply_rank() -> void:
	radius = RADII[rank]
	var circle := CircleShape2D.new()
	circle.radius = radius
	$CollisionShape2D.shape = circle
	queue_redraw()


func set_rank(new_rank: int) -> void:
	rank = new_rank
	_apply_rank()


# 合体で生まれた果物を「ポンッ」と膨らませる演出
func pop_in() -> void:
	draw_scale = 0.25
	queue_redraw()
	var t := create_tween()
	t.tween_method(_set_draw_scale, 0.25, 1.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_draw_scale(v: float) -> void:
	draw_scale = v
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(draw_scale, draw_scale))
	paint_face(self, radius, rank)


# 画像を使わず、顔つきの果物を任意の CanvasItem に描く（本体・NEXT・仕様メモで共用）
static func paint_face(ci: CanvasItem, r: float, fruit_rank: int, center := Vector2.ZERO) -> void:
	var body: Color = COLORS[fruit_rank]
	var dark := Color(0.16, 0.12, 0.12)
	var c := center

	ci.draw_circle(c, r, body)
	ci.draw_arc(c, r, 0.0, TAU, 64, body.darkened(0.35), maxf(2.0, r * 0.06), true)
	ci.draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.30, Color(1, 1, 1, 0.22))

	var eye_dx := r * 0.34
	var eye_y := -r * 0.06
	var eye_r := maxf(1.5, r * 0.11)
	if fruit_rank >= 9:
		var w := maxf(1.5, r * 0.05)
		ci.draw_arc(c + Vector2(-eye_dx, eye_y), r * 0.16, PI * 1.15, PI * 1.85, 12, dark, w, true)
		ci.draw_arc(c + Vector2(eye_dx, eye_y), r * 0.16, PI * 1.15, PI * 1.85, 12, dark, w, true)
	else:
		ci.draw_circle(c + Vector2(-eye_dx, eye_y), eye_r, dark)
		ci.draw_circle(c + Vector2(eye_dx, eye_y), eye_r, dark)
		ci.draw_circle(c + Vector2(-eye_dx + eye_r * 0.35, eye_y - eye_r * 0.35), eye_r * 0.4, Color(1, 1, 1, 0.85))
		ci.draw_circle(c + Vector2(eye_dx + eye_r * 0.35, eye_y - eye_r * 0.35), eye_r * 0.4, Color(1, 1, 1, 0.85))

	ci.draw_arc(c + Vector2(0, r * 0.10), r * 0.30, PI * 0.15, PI * 0.85, 20, dark, maxf(1.5, r * 0.07), true)

	if fruit_rank >= 4:
		ci.draw_circle(c + Vector2(-r * 0.52, r * 0.16), r * 0.14, Color(1, 0.5, 0.5, 0.30))
		ci.draw_circle(c + Vector2(r * 0.52, r * 0.16), r * 0.14, Color(1, 0.5, 0.5, 0.30))
