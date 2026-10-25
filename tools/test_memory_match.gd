extends SceneTree

# 神経衰弱 v1.3 のバグスイッチが狙いどおり動くかの確認。
# 実行: godot --headless --path . --script res://tools/test_memory_match.gd

var failed := 0


func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failed += 1


func make_game(bugs: Array) -> MemoryMatch:
	var game: MemoryMatch = load("res://scenes/titles/memory_match/memory_match.tscn").instantiate()
	root.add_child(game)
	game.start(bugs)
	return game


func cards(game: MemoryMatch) -> Array:
	return game.grid.get_children().filter(func(c): return not c.is_queued_for_deletion())


# 絵柄が違う3枚（a,b が不一致、c は別）を選ぶ
func three_different(game: MemoryMatch) -> Array:
	var cs := cards(game)
	var picked := [cs[0]]
	for c in cs:
		if picked.size() < 3 and picked.all(func(p): return p.symbol_index != c.symbol_index):
			picked.append(c)
	return picked


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# --- MM-HW-001 ---
	var g := make_game([])
	check(cards(g).all(func(c): return c.halloween), "001 OFF: 全カードがハロウィン絵柄")
	g.queue_free()
	g = make_game(["MM-HW-001"])
	var normal := cards(g).filter(func(c): return not c.halloween)
	check(normal.size() == 2 and normal.all(func(c): return c.symbol_index == MemoryMatch.BUG_001_SYMBOL), "001 ON: 1種類(2枚)だけ通常絵柄")
	g.queue_free()

	# --- MM-HW-002 ---
	g = make_game([])
	var p := three_different(g)
	g._on_card_pressed(p[0]); g._on_card_pressed(p[1]); g._on_card_pressed(p[2])
	check(not p[2].face_up, "002 OFF: 3枚目は表にならない")
	await wait(1.0)
	g.queue_free()

	g = make_game(["MM-HW-002"])
	p = three_different(g)
	g._on_card_pressed(p[0]); g._on_card_pressed(p[1])
	await wait(0.2)
	g._on_card_pressed(p[2])
	check(p[2].face_up and cards(g).filter(func(c): return c.face_up).size() == 3, "002 ON: 0.5秒以内なら3枚目も表になる")
	await wait(1.5)
	check(cards(g).all(func(c): return not c.face_up), "002 ON: 判定後は3枚とも裏に戻る")
	g._on_card_pressed(p[0]); g._on_card_pressed(p[1])
	await wait(0.7)
	g._on_card_pressed(p[2])
	check(not p[2].face_up, "002 ON: 0.5秒過ぎたら3枚目は押せない")
	await wait(1.0)
	g.queue_free()

	# --- MM-HW-003（全ペアをそろえてクリア） ---
	for bugs in [[], ["MM-HW-003"], ["MM-HW-001", "MM-HW-002", "MM-HW-003"]]:
		g = make_game(bugs)
		var got := [-1]
		g.cleared.connect(func(_m, medals): got[0] = medals)
		for i in MemoryMatch.PAIR_COUNT:
			var pair := cards(g).filter(func(c): return c.symbol_index == i)
			g._on_card_pressed(pair[0]); g._on_card_pressed(pair[1])
			await wait(0.6 if bugs.has("MM-HW-002") else 0.05)
		var expect := 1 if bugs.has("MM-HW-003") else 3
		check(got[0] == expect and g.clear_panel.visible, "003 %s: クリア報酬 x%d（実際 x%d）" % [str(bugs), expect, got[0]])
		g.queue_free()

	# --- MM-HW-002 の修正確認：バグOFFで素早く3枚目を押すと「出なかった」 ---
	g = make_game([])
	var checked := []
	g.bug_checked.connect(func(id, occurred): checked.append([id, occurred]))
	p = three_different(g)
	g._on_card_pressed(p[0]); g._on_card_pressed(p[1]); g._on_card_pressed(p[2])
	check(checked.has(["MM-HW-002", false]), "002 OFF: 素早く3枚目 → 出なかった（修正確認できる）")
	await wait(1.0)
	g.queue_free()

	# --- MM-HW-004〜007（1日目には起きないバグ候補） ---
	for on in [false, true]:
		var tag := "ON" if on else "OFF"
		g = make_game(["MM-HW-004", "MM-HW-005", "MM-HW-006", "MM-HW-007"] if on else [])
		check(g.banner_label.text.ends_with("10/30" if on else "10/31"), "005 %s: バナーの期間" % tag)
		var pair := cards(g).filter(func(c): return c.symbol_index == 0)
		g._on_card_pressed(pair[0]); g._on_card_pressed(pair[1])
		check(g.moves == (0 if on else 1), "004 %s: ペアがそろった時の手数 %d" % [tag, g.moves])
		var one: MemoryCard = cards(g).filter(func(c): return c.symbol_index == 2)[0]
		g._on_card_pressed(one); g._on_card_pressed(one)
		check(one.matched == on, "006 %s: 同じカード2回タップで1枚ペア=%s" % [tag, one.matched])
		if not on:
			await wait(0.05)
			one.flip_down(); g.flipped.clear()
		var ghost: MemoryCard = cards(g).filter(func(c): return c.symbol_index == 1)[0]
		var skull: MemoryCard = cards(g).filter(func(c): return c.symbol_index == 6)[0]
		g._on_card_pressed(ghost); g._on_card_pressed(skull)
		await wait(0.05)
		check(ghost.matched == on and skull.matched == on, "007 %s: おばけとドクロがペア=%s" % [tag, ghost.matched])
		await wait(1.0)
		g.queue_free()

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
