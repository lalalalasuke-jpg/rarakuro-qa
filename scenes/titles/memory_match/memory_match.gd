class_name MemoryMatch
extends Control

# 作中タイトル「神経衰弱」。元の memory-match をベースに、バグの「スイッチ」を差し込んである。
# 版（edition）が2つある：
#   "halloween" … v1.3 ハロウィンイベント（1日目。バグ MM-HW-001〜007）
#   "autumn"    … v1.4 紅葉狩りイベント（3日目。v1.3 の修正入り＋タイマー・特効。バグ MM-AU-01〜11）
# 版は configure() で、どのバグを起こすかは start() に渡す ID の一覧で決まる（データは res://data/bugs.json）。

signal cleared(moves: int, medals: int)
## そのバグが起きるはずの操作をした時に出す。occurred=true ならバグが画面に出た（＝見た）、
## false なら同じ操作でバグが出なかった（＝修正確認に使う）
signal bug_checked(id: String, occurred: bool)

const CARD := preload("res://scenes/titles/memory_match/card.tscn")
## ペアの数（カード枚数はこの2倍）
const PAIR_COUNT := 8
## 揃わなかった時、裏返すまでの待ち時間
const MISMATCH_DELAY := 0.8
## 仕様どおりのクリア報酬（イベント仕様メモ「クリアで ◯◯メダル ×3」）
const CLEAR_MEDALS := 3
const RULE_TEXT := "カードを2枚めくって、同じ絵柄をそろえよう！"
## 版ごとの設定
const EDITIONS := {
	"halloween": {"banner": "HALLOWEEN EVENT  10/26 - 10/31", "reward": "かぼちゃメダル", "timer": false},
	"autumn": {"banner": "MOMIJI EVENT  11/8 - 11/14", "reward": "もみじメダル", "timer": true},
}
## v1.4: この秒数以内にクリアするとメダルが増える
const FAST_CLEAR_SEC := 60.0
const FAST_CLEAR_MEDALS := 5
## v1.4 特効：もみじ（0番）のペアをそろえるとタイマーが戻る秒数
const MOMIJI_SYMBOL := 0
const MOMIJI_BONUS_SEC := 5.0

## MM-HW-001: 通常の絵柄のまま残ってしまう1種類（キャンディ。毎回同じ＝必ず再現できる）
const BUG_001_SYMBOL := 5
## MM-HW-002 / MM-AU-01: 2枚目をめくってから判定が始まるまでの隙間（この間は他のカードも押せてしまう）
const BUG_002_WINDOW := 0.5
## MM-HW-003: 間違ったクリア報酬
const BUG_003_MEDALS := 1
## MM-HW-005: 間違ったイベント期間の表示
const BUG_005_BANNER := "HALLOWEEN EVENT  10/26 - 10/30"
## MM-HW-007: 同じ絵柄あつかいされてしまう組み合わせ（おばけとドクロ）
const BUG_007_PAIR := [1, 6]
## MM-AU-07: 文字化けしたルール説明
const BUG_AU07_RULE := "繧ｫ繝ｼ繝峨ｒ2譫壹ａ縺上▲縺ｦ縲∝酔縺倡ｵｵ譟縺繧偵◎繧阪∴繧医≧縺ｼ縺"
## MM-AU-08: ハロウィンの絵柄が残ってしまう1種類（さつまいもの場所に、キャンディ）
const BUG_AU08_SYMBOL := 5
## MM-AU-11: 間違ったイベント期間の表示
const BUG_AU11_BANNER := "MOMIJI EVENT  11/8 - 11/4"

var edition := "halloween"
var moves := 0
var matches := 0
# 今表向きになっていて、まだ判定してないカード（バグ002の時は3枚以上になりうる）
var flipped: Array[MemoryCard] = []
var busy := false
var bugs: Array = []
# 2枚目をめくった時刻（ミリ秒）。MM-HW-002 の操作をしたかの判定に使う
var second_flip_msec := -100000
# このプレイでカードを触ったか（バナーなどの「画面を見た」判定用）
var touched := false
# v1.4: 経過時間（秒）とタイマーが動いているか
var elapsed := 0.0
var timer_running := false
# v1.4: 直前の2枚が外れた（次の1回目のタップが MM-AU-02 の操作）
var after_miss := false

@onready var grid: GridContainer = $Grid
@onready var banner_label: Label = $Banner/BannerLabel
@onready var moves_label: Label = $MovesLabel
@onready var matches_label: Label = $MatchesLabel
@onready var time_label: Label = $TimeLabel
@onready var special_label: Label = $SpecialLabel
@onready var rule_label: Label = $RuleLabel
@onready var clear_panel: Control = $ClearPanel
@onready var clear_moves_label: Label = $ClearPanel/ClearMoves
@onready var clear_reward_label: Label = $ClearPanel/ClearReward


func _ready() -> void:
	$ClearPanel/Replay.pressed.connect(func(): start(bugs))


# 版を切り替える（data/dayN.json の title_options から呼ばれる）
func configure(options: Dictionary) -> void:
	edition = options.get("edition", "halloween")
	$Banner.color = Color(0.8, 0.3, 0.15) if edition == "autumn" else Color(0.95, 0.55, 0.16)


func has_bug(id: String) -> bool:
	return bugs.has(id)


func _check(id: String) -> void:
	bug_checked.emit(id, has_bug(id))


func _ed() -> Dictionary:
	return EDITIONS[edition]


# 新しく1回分のプレイを始める。enabled_bugs は有効にするバグの ID 一覧
func start(enabled_bugs: Array) -> void:
	bugs = enabled_bugs
	moves = 0
	matches = 0
	flipped.clear()
	busy = false
	after_miss = false
	elapsed = 0.0
	timer_running = false
	clear_panel.visible = false
	special_label.visible = false
	for child in grid.get_children():
		child.queue_free()
	_build_grid()
	_update_hud()
	# ★バグ MM-HW-005 / MM-AU-11: イベント期間の表示が仕様と違う。画面を開けば見える
	# （「見た」扱いにするのは、そのプレイで最初にカードを触った時）
	if has_bug("MM-HW-005"):
		banner_label.text = BUG_005_BANNER
	elif has_bug("MM-AU-11"):
		banner_label.text = BUG_AU11_BANNER
	else:
		banner_label.text = _ed().banner
	# ★バグ MM-AU-07: ルール説明をマスタから読むようにしたら、文字化けしている
	rule_label.text = BUG_AU07_RULE if has_bug("MM-AU-07") else RULE_TEXT
	time_label.visible = _ed().timer
	touched = false


func _process(delta: float) -> void:
	if not timer_running:
		return
	elapsed += delta
	_update_time()


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
		card.style = edition
		card.back_style = edition
		# ★バグ MM-HW-001: 1種類だけハロウィン絵柄への差し替え漏れ
		card.halloween = not (has_bug("MM-HW-001") and idx == BUG_001_SYMBOL)
		# ★バグ MM-AU-08: 秋の絵柄への差し替え漏れ（前のイベントのキャンディが残っている）
		if has_bug("MM-AU-08") and idx == BUG_AU08_SYMBOL:
			card.style = "halloween"
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
		for id in ["MM-HW-005", "MM-AU-11", "MM-AU-07"]:
			_check(id)
	if busy:
		# 判定中に別のカードを押した＝ MM-HW-002 / MM-AU-01 の操作（バグが無ければ何も起きない）
		if not card.face_up and not card.matched \
				and Time.get_ticks_msec() - second_flip_msec <= BUG_002_WINDOW * 1000:
			_check("MM-HW-002")
			_check("MM-AU-01")
		return
	if card.matched:
		return
	if after_miss:
		# 外れたあとの1回目のタップ＝ MM-AU-02 の操作
		after_miss = false
		_check("MM-AU-02")
		if has_bug("MM-AU-02"):
			return  # ★バグ MM-AU-02: 002 の修正の副作用で、外れたあとの1回目のタップが効かない
	if card.face_up:
		if flipped.size() == 1 and flipped[0] == card:
			_check("MM-HW-006")
			_check("MM-AU-04")
			if has_bug("MM-HW-006"):
				# ★バグ MM-HW-006: 同じカードを2回タップすると、その1枚だけでペア成立になる
				card.set_matched()
				matches += 1
				moves += 1
				flipped.clear()
				_update_hud()
				if matches == PAIR_COUNT:
					_on_clear()
			elif has_bug("MM-AU-04"):
				# ★バグ MM-AU-04: 006 の修正の副作用で、表のカードを押すと裏に戻ってしまう
				card.flip_down()
				flipped.clear()
		return

	card.flip_up()
	flipped.append(card)
	if _ed().timer and not timer_running and matches < PAIR_COUNT:
		timer_running = true  # v1.4: 最初の1枚をめくったらタイマー開始
	if card.symbol_index == BUG_001_SYMBOL:
		_check("MM-HW-001")
		_check("MM-AU-08")
	if flipped.size() == 3:
		_check("MM-HW-002")
		_check("MM-AU-01")
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
		_check("MM-AU-03")
	# ★バグ MM-HW-004: ペアがそろった時だけ手数が増えない
	if not (same and has_bug("MM-HW-004")):
		moves += 1
	# ★バグ MM-AU-03: 004 の修正の副作用で、ペアがそろうと手数がもう1つ増える
	if same and has_bug("MM-AU-03"):
		moves += 1
	_update_hud()
	if has_bug("MM-HW-002") or has_bug("MM-AU-01"):
		# ★バグ MM-HW-002 / MM-AU-01（デグレ）: 本来は2枚目をめくった瞬間に操作を止めるべきなのに、
		# 判定を始めるまで少し待つ間 busy にしていない → この隙に3枚目が押せる
		await get_tree().create_timer(BUG_002_WINDOW).timeout
	busy = true

	var extra := flipped.slice(2)
	if same:
		a.set_matched()
		b.set_matched()
		matches += 1
		_update_hud()
		if edition == "autumn" and a.symbol_index == MOMIJI_SYMBOL:
			_on_momiji()
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
		after_miss = true
	flipped.clear()
	busy = false
	if matches == PAIR_COUNT:
		_on_clear()


# v1.4 特効：もみじのペアでタイマーが5秒戻る
func _on_momiji() -> void:
	_check("MM-AU-05")
	if has_bug("MM-AU-05"):
		return  # ★バグ MM-AU-05: マスタ修正のときに、もみじの特効の設定まで消してしまった
	elapsed = maxf(0.0, elapsed - MOMIJI_BONUS_SEC)
	_update_time()
	special_label.text = "特効！ −%d秒" % int(MOMIJI_BONUS_SEC)
	special_label.visible = true
	get_tree().create_timer(1.5).timeout.connect(func(): special_label.visible = false)


func _on_clear() -> void:
	var medals := CLEAR_MEDALS
	var reward_name: String = _ed().reward
	if edition == "halloween":
		# ★バグ MM-HW-003: 報酬の数がイベント仕様メモ（×3）と違う
		if has_bug("MM-HW-003"):
			medals = BUG_003_MEDALS
		_check("MM-HW-003")
	else:
		timer_running = false
		if elapsed <= FAST_CLEAR_SEC:
			_check("MM-AU-09")
			# ★バグ MM-AU-09: 60秒以内にクリアしても、ボーナスのメダルにならない
			if not has_bug("MM-AU-09"):
				medals = FAST_CLEAR_MEDALS
		_check("MM-AU-10")
		# ★バグ MM-AU-10: クリアしてもタイマーが止まらない
		timer_running = has_bug("MM-AU-10")
		_check("MM-AU-06")
		# ★バグ MM-AU-06: 報酬名をマスタから出すようにしたが、前のイベントの名前が入っている
		if has_bug("MM-AU-06"):
			reward_name = "かぼちゃメダル"
	clear_reward_label.text = "報酬：%s ×%d" % [reward_name, medals]
	clear_panel.visible = true
	_update_time()
	cleared.emit(moves, medals)


func _update_hud() -> void:
	moves_label.text = "MOVES %d" % moves
	matches_label.text = "PAIRS %d/%d" % [matches, PAIR_COUNT]
	_update_time()


func _update_time() -> void:
	time_label.text = "TIME %.1f" % elapsed
	if _ed().timer:
		clear_moves_label.text = "MOVES %d　TIME %.1f" % [moves, elapsed]
	else:
		clear_moves_label.text = "MOVES %d" % moves
