class_name MemoryMatch
extends Control

# 作中タイトル「神経衰弱」v1.3（ハロウィンイベント）。
# 元の memory-match をベースに、バグの「スイッチ」を差し込んである。
# どのバグを起こすかは start() に渡す ID の一覧で決まる（データは res://data/bugs.json）。
# バグ候補は7つ。どの日にどれを起こすかは data/dayN.json で決める。

signal cleared(moves: int, medals: int)
## そのバグが起きるはずの操作をした時に出す。occurred=true ならバグが画面に出た（＝見た）、
## false なら同じ操作でバグが出なかった（＝修正確認に使う）
signal bug_checked(id: String, occurred: bool)

const CARD := preload("res://scenes/titles/memory_match/card.tscn")
## ペアの数（カード枚数はこの2倍）
const PAIR_COUNT := 8
## 揃わなかった時、裏返すまでの待ち時間
const MISMATCH_DELAY := 0.8
## 仕様どおりのクリア報酬（イベント仕様メモ「クリアで かぼちゃメダル ×3」）
const CLEAR_MEDALS := 3
const BANNER_TEXT := "HALLOWEEN EVENT  10/26 - 10/31"

## MM-HW-001: 通常の絵柄のまま残ってしまう1種類（キャンディ。毎回同じ＝必ず再現できる）
const BUG_001_SYMBOL := 5
## MM-HW-002: 2枚目をめくってから判定が始まるまでの隙間（この間は他のカードも押せてしまう）
const BUG_002_WINDOW := 0.5
## MM-HW-003: 間違ったクリア報酬
const BUG_003_MEDALS := 1
## MM-HW-005: 間違ったイベント期間の表示
const BUG_005_BANNER := "HALLOWEEN EVENT  10/26 - 10/30"
## MM-HW-007: 同じ絵柄あつかいされてしまう組み合わせ（おばけとドクロ）
const BUG_007_PAIR := [1, 6]

var moves := 0
var matches := 0
# 今表向きになっていて、まだ判定してないカード（バグ002の時は3枚以上になりうる）
var flipped: Array[MemoryCard] = []
var busy := false
var bugs: Array = []
# 2枚目をめくった時刻（ミリ秒）。MM-HW-002 の操作をしたかの判定に使う
var second_flip_msec := -100000
# このプレイでカードを触ったか（MM-HW-005 の「画面を見た」判定用）
var touched := false

@onready var grid: GridContainer = $Grid
@onready var banner_label: Label = $Banner/BannerLabel
@onready var moves_label: Label = $MovesLabel
@onready var matches_label: Label = $MatchesLabel
@onready var clear_panel: Control = $ClearPanel
@onready var clear_moves_label: Label = $ClearPanel/ClearMoves
@onready var clear_reward_label: Label = $ClearPanel/ClearReward


func _ready() -> void:
	$ClearPanel/Replay.pressed.connect(func(): start(bugs))


func has_bug(id: String) -> bool:
	return bugs.has(id)


func _check(id: String) -> void:
	bug_checked.emit(id, has_bug(id))


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
	# ★バグ MM-HW-005: イベント期間の表示が仕様（10/31まで）と違う。画面を開けば見える
	# （「見た」扱いにするのは、そのプレイで最初にカードを触った時）
	banner_label.text = BUG_005_BANNER if has_bug("MM-HW-005") else BANNER_TEXT
	touched = false


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


func _is_pair(a: MemoryCard, b: MemoryCard) -> bool:
	if a.symbol_index == b.symbol_index:
		return true
	# ★バグ MM-HW-007: おばけとドクロを同じ絵柄あつかいしてしまう
	return has_bug("MM-HW-007") and BUG_007_PAIR.has(a.symbol_index) and BUG_007_PAIR.has(b.symbol_index)


func _on_card_pressed(card: MemoryCard) -> void:
	if not touched:
		touched = true
		_check("MM-HW-005")
	if busy:
		# 判定中に別のカードを押した＝ MM-HW-002 の操作（バグが無ければ何も起きない）
		if not card.face_up and not card.matched \
				and Time.get_ticks_msec() - second_flip_msec <= BUG_002_WINDOW * 1000:
			_check("MM-HW-002")
		return
	if card.matched:
		return
	if card.face_up:
		if flipped.size() == 1 and flipped[0] == card:
			_check("MM-HW-006")
			if has_bug("MM-HW-006"):
				# ★バグ MM-HW-006: 同じカードを2回タップすると、その1枚だけでペア成立になる
				card.set_matched()
				matches += 1
				moves += 1
				flipped.clear()
				_update_hud()
				if matches == PAIR_COUNT:
					_on_clear()
		return

	card.flip_up()
	flipped.append(card)
	if card.symbol_index == BUG_001_SYMBOL:
		_check("MM-HW-001")
	if flipped.size() == 3:
		_check("MM-HW-002")
	if flipped.size() != 2:
		# 1枚目、またはバグ002で3枚目以降をめくった時はここで終わり
		return

	second_flip_msec = Time.get_ticks_msec()
	var a := flipped[0]
	var b := flipped[1]
	var same := _is_pair(a, b)
	if BUG_007_PAIR.has(a.symbol_index) and BUG_007_PAIR.has(b.symbol_index) and a.symbol_index != b.symbol_index:
		_check("MM-HW-007")
	if same:
		_check("MM-HW-004")
	# ★バグ MM-HW-004: ペアがそろった時だけ手数が増えない
	if not (same and has_bug("MM-HW-004")):
		moves += 1
	_update_hud()
	if has_bug("MM-HW-002"):
		# ★バグ MM-HW-002: 本来は2枚目をめくった瞬間に操作を止めるべきなのに、
		# 判定を始めるまで少し待つ間 busy にしていない → この隙に3枚目が押せる
		await get_tree().create_timer(BUG_002_WINDOW).timeout
	busy = true

	var extra := flipped.slice(2)
	if same:
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
	_check("MM-HW-003")
	cleared.emit(moves, medals)


func _update_hud() -> void:
	moves_label.text = "MOVES %d" % moves
	matches_label.text = "PAIRS %d/%d" % [matches, PAIR_COUNT]
