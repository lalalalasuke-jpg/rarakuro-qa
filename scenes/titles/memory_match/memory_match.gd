class_name MemoryMatch
extends Control

# 作中タイトル「神経衰弱」v1.3（ハロウィンイベント）。
# 元の memory-match をベースに、バグの「スイッチ」を差し込んである。
# どのバグを起こすかは start() に渡す ID の一覧で決まる（データは res://data/bugs.json）。

signal cleared(moves: int, medals: int)

const CARD := preload("res://scenes/titles/memory_match/card.tscn")
## ペアの数（カード枚数はこの2倍）
const PAIR_COUNT := 8
## 揃わなかった時、裏返すまでの待ち時間
const MISMATCH_DELAY := 0.8
## 仕様どおりのクリア報酬（イベント仕様メモ「クリアで かぼちゃメダル ×3」）
const CLEAR_MEDALS := 3

## MM-HW-001: 通常の絵柄のまま残ってしまう1種類（毎回同じ＝必ず再現できる）
const BUG_001_SYMBOL := 5
## MM-HW-002: 2枚目をめくってから判定が始まるまでの隙間（この間は他のカードも押せてしまう）
const BUG_002_WINDOW := 0.5
## MM-HW-003: 間違ったクリア報酬
const BUG_003_MEDALS := 1

var moves := 0
var matches := 0
# 今表向きになっていて、まだ判定してないカード（バグ002の時は3枚以上になりうる）
var flipped: Array[MemoryCard] = []
var busy := false
var bugs: Array = []

@onready var grid: GridContainer = $Grid
@onready var moves_label: Label = $MovesLabel
@onready var matches_label: Label = $MatchesLabel
@onready var clear_panel: Control = $ClearPanel
@onready var clear_moves_label: Label = $ClearPanel/ClearMoves
@onready var clear_reward_label: Label = $ClearPanel/ClearReward


func has_bug(id: String) -> bool:
	return bugs.has(id)


# 新しく1回分のプレイを始める。enabled_bugs は有効にするバグの ID 一覧
func start(enabled_bugs: Array) -> void:
	bugs = enabled_bugs
	moves = 0
	matches = 0
	flipped.clear()
	busy = false
	clear_panel.visible = false
	for child in grid.get_children():
		child.queue_free()
	_build_grid()
	_update_hud()


# ペアぶんの絵柄を2枚ずつ用意してシャッフルし、カードを並べる
func _build_grid() -> void:
	var symbol_indices: Array[int] = []
	for i in PAIR_COUNT:
		symbol_indices.append(i)
		symbol_indices.append(i)
	symbol_indices.shuffle()

	for idx in symbol_indices:
		var card: MemoryCard = CARD.instantiate()
		card.symbol_index = idx
		# ★バグ MM-HW-001: 1種類だけハロウィン絵柄への差し替え漏れ
		card.halloween = not (has_bug("MM-HW-001") and idx == BUG_001_SYMBOL)
		card.pressed.connect(_on_card_pressed.bind(card))
		grid.add_child(card)


func _on_card_pressed(card: MemoryCard) -> void:
	if busy or card.face_up or card.matched:
		return
	card.flip_up()
	flipped.append(card)
	if flipped.size() != 2:
		# 1枚目、またはバグ002で3枚目以降をめくった時はここで終わり
		return

	moves += 1
	_update_hud()
	if has_bug("MM-HW-002"):
		# ★バグ MM-HW-002: 本来は2枚目をめくった瞬間に操作を止めるべきなのに、
		# 判定を始めるまで少し待つ間 busy にしていない → この隙に3枚目が押せる
		await get_tree().create_timer(BUG_002_WINDOW).timeout
	busy = true

	var a := flipped[0]
	var b := flipped[1]
	var extra := flipped.slice(2)
	if a.symbol_index == b.symbol_index:
		a.set_matched()
		b.set_matched()
		matches += 1
		_update_hud()
		if not extra.is_empty():
			await get_tree().create_timer(MISMATCH_DELAY).timeout
			for c in extra:
				c.flip_down()
	else:
		await get_tree().create_timer(MISMATCH_DELAY).timeout
		a.flip_down()
		b.flip_down()
		for c in extra:
			c.flip_down()
	flipped.clear()
	busy = false
	if matches == PAIR_COUNT:
		_on_clear()


func _on_clear() -> void:
	# ★バグ MM-HW-003: 報酬の数がイベント仕様メモ（×3）と違う
	var medals := BUG_003_MEDALS if has_bug("MM-HW-003") else CLEAR_MEDALS
	clear_moves_label.text = "MOVES %d" % moves
	clear_reward_label.text = "報酬：かぼちゃメダル ×%d" % medals
	clear_panel.visible = true
	cleared.emit(moves, medals)


func _update_hud() -> void:
	moves_label.text = "MOVES %d" % moves
	matches_label.text = "PAIRS %d/%d" % [matches, PAIR_COUNT]
