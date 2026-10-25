class_name SuikaTitle
extends Control

# 作中タイトル「スイカゲーム」v2.1（秋の味覚フェア）。元の suika-game をベースに、バグの「スイッチ」を差し込んである。
# 物理演算（果物が落ちて転がる）はモニターの中の小さな別画面（SubViewport）の中で動かす。
# どのバグを起こすかは start() に渡す ID の一覧で決まる（データは res://data/bugs.json の SK-xx）。

signal cleared(score: int, acorns: int)
## そのバグが起きるはずの操作をした時に出す。occurred=true ならバグが画面に出た（＝見た）、
## false なら同じ操作でバグが出なかった（＝修正確認に使う）
signal bug_checked(id: String, occurred: bool)

const FRUIT := preload("res://scenes/titles/suika/fruit.tscn")

## 果物を持って待つ高さ（SubViewport の中の座標）
const DROP_Y := 45.0
## 箱の内側の壁の X と、底の Y
const BIN_LEFT := 110.0
const BIN_RIGHT := 610.0
const FLOOR_Y := 690.0
## この Y より上に果物が居座ったらアウト
const LINE_Y := 100.0
const COOLDOWN := 0.6
const SPAWN_MAX_RANK := 2
const GAME_OVER_DELAY := 1.5
## 前の合体からこの秒数以内に次が合体したらコンボ
const COMBO_WINDOW := 1.2
## イベント：かきを作るとボーナス
const KAKI_RANK := 4
const KAKI_BONUS := 50
## 報酬：スコアこの点ごとにどんぐり1個
const ACORN_PER := 500
const BANNER_TEXT := "秋の味覚フェア　11/1 - 11/7"

## SK-01: バナーの誤字
const BUG_01_BANNER := "秋の味角フェア　11/1 - 11/7"
## SK-07: どんぐりの計算が1000点ごとになっている
const BUG_07_ACORN_PER := 1000
## SK-08: 左の壁ぎりぎりまで寄せられない（この分だけ内側で止まる）
const BUG_08_LEFT_GAP := 70.0
## SK-09: 底のこの範囲だけトランポリンのように跳ねる
const BUG_09_FROM := 300.0
const BUG_09_TO := 420.0
## SK-12: 文字化けしたバナー
const BUG_12_BANNER := "遘九縺ｮ蜻ｳ隕壹ヵ繧ｧ繧｢　11/1 - 11/7"

var bugs: Array = []
var current_fruit: SuikaFruit = null
var can_drop := true
var score := 0
var next_rank := 0
var game_over := false
var aim_x := 360.0
var danger_time := 0.0
var combo := 0
var last_merge_sec := -999.0
# このプレイで画面を触ったか（バナーのバグの「見た」判定用）
var touched := false
# start() のたびに増やし、古いプレイの待ち（クールダウン）を無効にする
var play_id := 0

@onready var banner_label: Label = $Banner/BannerLabel
@onready var score_label: Label = $ScoreLabel
@onready var next_icon: SuikaFruitIcon = $NextIcon
@onready var play_area: SubViewportContainer = $PlayArea
## 遊ぶ場所の上に重ねた透明な入力受け（座標は SubViewport の中と同じ）
@onready var touch_area: Control = $Touch
@onready var world: Node2D = $PlayArea/SubViewport/World
@onready var fruits: Node2D = $PlayArea/SubViewport/World/Fruits
@onready var right_wall: CollisionShape2D = $PlayArea/SubViewport/World/Bin/RightWall
@onready var floor_mid: StaticBody2D = $PlayArea/SubViewport/World/FloorMid
@onready var danger_line: Line2D = $PlayArea/SubViewport/World/GameOverLine
@onready var drop_guide: Line2D = $PlayArea/SubViewport/World/DropGuide
@onready var game_over_panel: Control = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/FinalScore
@onready var reward_label: Label = $GameOverPanel/Reward


func _ready() -> void:
	touch_area.gui_input.connect(_on_play_input)
	$GameOverPanel/Replay.pressed.connect(func(): start(bugs))


func has_bug(id: String) -> bool:
	return bugs.has(id)


func _check(id: String) -> void:
	bug_checked.emit(id, has_bug(id))


# 新しく1回分のプレイを始める。enabled_bugs は有効にするバグの ID 一覧
func start(enabled_bugs: Array) -> void:
	bugs = enabled_bugs
	play_id += 1
	for f in fruits.get_children():
		f.queue_free()
	current_fruit = null
	can_drop = true
	score = 0
	game_over = false
	danger_time = 0.0
	combo = 0
	last_merge_sec = -999.0
	touched = false
	game_over_panel.visible = false

	# ★バグ SK-01 / SK-11 / SK-12: バナーの文字（誤字・表示されない・文字化け）
	if has_bug("SK-11"):
		banner_label.text = ""
	elif has_bug("SK-12"):
		banner_label.text = BUG_12_BANNER
	elif has_bug("SK-01"):
		banner_label.text = BUG_01_BANNER
	else:
		banner_label.text = BANNER_TEXT
	# ★バグ SK-03: 右の壁の当たり判定が無い（＋右端の寄せすぎを止めていない）
	right_wall.disabled = has_bug("SK-03")
	# ★バグ SK-09: 底の真ん中の一部だけ、跳ね返りの設定が入ってしまっている
	floor_mid.physics_material_override.bounce = 0.95 if has_bug("SK-09") else 0.0

	next_rank = randi() % (SPAWN_MAX_RANK + 1)
	next_icon.show_rank(next_rank)
	_update_score()
	_spawn_next(true)


func _process(delta: float) -> void:
	if game_over:
		return
	if current_fruit != null:
		current_fruit.position.x = _clamp_x(aim_x, current_fruit.radius)
	_update_drop_guide()
	_check_game_over(delta)
	_update_danger_line()
	# 箱の外に落ちていった果物は片付ける
	for f in fruits.get_children():
		if f.position.y > FLOOR_Y + 300.0:
			f.queue_free()


# 持っている果物を寄せられる範囲
func _clamp_x(x: float, r: float) -> float:
	var lo := BIN_LEFT + r
	var hi := BIN_RIGHT - r
	if has_bug("SK-08"):
		lo += BUG_08_LEFT_GAP  # ★バグ SK-08: 左の壁ぎりぎりまで寄せられない
	if has_bug("SK-03"):
		hi = BIN_RIGHT + r * 0.3  # ★バグ SK-03: 右は壁を越えて寄せられてしまう
	return clampf(x, lo, hi)


func _on_play_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseMotion:
		aim_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		aim_x = event.position.x
		if event.pressed and not touched:
			touched = true
			for id in ["SK-01", "SK-11", "SK-12"]:
				_check(id)
		if not event.pressed:
			_drop()


func _drop() -> void:
	if game_over or not can_drop or current_fruit == null:
		return
	var r := current_fruit.radius
	# 左右の端に寄せて落としたか（SK-08 / SK-03 の操作）
	if aim_x <= BIN_LEFT + r + BUG_08_LEFT_GAP:
		_check("SK-08")
	if aim_x >= BIN_RIGHT - r - 2.0:
		_check("SK-03")
	current_fruit.freeze = false
	current_fruit = null
	can_drop = false
	var my_play := play_id
	await get_tree().create_timer(COOLDOWN).timeout
	if my_play != play_id:
		return
	can_drop = true
	_spawn_next()


func _spawn_next(first := false) -> void:
	if game_over:
		return
	var rank := next_rank
	if not first:
		_check("SK-02")
		if has_bug("SK-02"):
			# ★バグ SK-02: NEXT に出ていたのと違う果物が出てくる
			rank = (rank + 1) % (SPAWN_MAX_RANK + 1)
	next_rank = randi() % (SPAWN_MAX_RANK + 1)
	next_icon.show_rank(next_rank)
	var f := _make_fruit(rank)
	f.freeze = true
	f.position = Vector2(_clamp_x(aim_x, f.radius), DROP_Y)
	fruits.add_child(f)
	current_fruit = f


func _make_fruit(rank: int) -> SuikaFruit:
	var f: SuikaFruit = FRUIT.instantiate()
	f.rank = rank
	f.contact.connect(_on_contact)
	return f


# 果物が何かにぶつかった（物理計算の途中で呼ばれるので、ノードの増減は次フレームに回す）
func _on_contact(a: SuikaFruit, other: Node) -> void:
	if other == floor_mid:
		_check("SK-09")
		return
	if not (other is SuikaFruit):
		return
	var b := other as SuikaFruit
	if a.merged or b.merged or a == current_fruit or b == current_fruit:
		return
	# A↔B の通知は両方に飛ぶ。ID が小さい方だけが処理して1回に絞る
	if a.get_instance_id() > b.get_instance_id():
		return
	if a.rank == b.rank:
		if a.rank >= SuikaFruit.MAX_RANK:
			return
		a.merged = true
		b.merged = true
		_resolve_merge.call_deferred(a, b, a.rank + 1)
		return
	var ranks := [a.rank, b.rank]
	if ranks.has(1) and ranks.has(2):
		_check("SK-04")
		if has_bug("SK-04"):
			# ★バグ SK-04: いちごとぶどうが合体してしまう
			a.merged = true
			b.merged = true
			_resolve_merge.call_deferred(a, b, 3)
			return
	if ranks.has(2):
		_check("SK-10")
		if has_bug("SK-10"):
			# ★バグ SK-10: ぶどうにぶつかった果物がくっついて止まる
			var stuck := b if a.rank == 2 else a
			_stick.call_deferred(stuck)


func _stick(f: SuikaFruit) -> void:
	if is_instance_valid(f) and not f.merged:
		f.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		f.freeze = true


func _resolve_merge(a: SuikaFruit, b: SuikaFruit, new_rank: int) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	if a.rank == 3 and b.rank == 3:
		_check("SK-13")
		if has_bug("SK-13"):
			new_rank = 5  # ★バグ SK-13: デコポンが合体すると、かきを飛ばしてりんごになる
	var pos: Vector2 = (a.position + b.position) * 0.5

	var now := Time.get_ticks_msec() / 1000.0
	combo = combo + 1 if now - last_merge_sec <= COMBO_WINDOW else 1
	last_merge_sec = now
	var multiplier := combo
	if combo >= 2:
		_check("SK-06")
		if has_bug("SK-06"):
			multiplier = 1  # ★バグ SK-06: コンボになっても点数が倍にならない
	var gained := (new_rank + 1) * 10 * multiplier
	if new_rank == KAKI_RANK:
		_check("SK-05")
		if not has_bug("SK-05"):  # ★バグ SK-05: かきのボーナスが入らない
			gained += KAKI_BONUS
	score += gained
	_update_score()
	_popup_text(pos, "+%d" % gained, Color(1, 0.95, 0.5))
	if combo >= 2:
		_popup_text(pos + Vector2(0, -40), "COMBO x%d" % combo, Color(1, 0.7, 0.4))

	a.queue_free()
	b.queue_free()
	var f := _make_fruit(new_rank)
	f.position = pos
	fruits.add_child(f)
	f.pop_in()


func _popup_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos - Vector2(60, 20)
	l.z_index = 50
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	world.add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 60.0, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8)
	t.chain().tween_callback(l.queue_free)


func _update_drop_guide() -> void:
	if current_fruit == null:
		drop_guide.visible = false
		return
	var x := current_fruit.position.x
	drop_guide.visible = true
	drop_guide.points = PackedVector2Array([Vector2(x, DROP_Y + current_fruit.radius), Vector2(x, FLOOR_Y)])


func _update_danger_line() -> void:
	if danger_time > 0.0:
		danger_line.default_color = Color(1, 0.25, 0.25, 0.35 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.013)))
		danger_line.width = 5.0
	else:
		danger_line.default_color = Color(0.9, 0.3, 0.3, 0.55)
		danger_line.width = 3.0


# 落ちて止まっている果物がラインを超えていないか毎フレーム確認
func _check_game_over(delta: float) -> void:
	var over_line := false
	for f in fruits.get_children():
		if f == current_fruit or f.is_queued_for_deletion():
			continue
		if f.position.y - f.radius < LINE_Y and f.linear_velocity.length() < 60.0:
			over_line = true
			break
	if over_line:
		danger_time += delta
		if danger_time >= GAME_OVER_DELAY:
			_do_game_over()
	else:
		danger_time = 0.0


func _do_game_over() -> void:
	game_over = true
	if current_fruit != null:
		current_fruit.queue_free()
		current_fruit = null
	drop_guide.visible = false
	danger_time = 0.0
	_update_danger_line()
	var acorns := acorns_for(score)
	if score >= ACORN_PER:
		_check("SK-07")
		_check("SK-14")
	final_score_label.text = "SCORE %d" % score
	reward_label.text = "報酬：どんぐり ×%d" % acorns
	game_over_panel.visible = true
	cleared.emit(score, acorns)


# スコアからどんぐりの数を出す
func acorns_for(s: int) -> int:
	if has_bug("SK-14"):
		return 0  # ★バグ SK-14: どんぐりの計算が入っていない
	if has_bug("SK-07"):
		return floori(float(s) / BUG_07_ACORN_PER)  # ★バグ SK-07: 1000点ごとになっている
	return floori(float(s) / ACORN_PER)


func _update_score() -> void:
	score_label.text = "SCORE %d" % score
