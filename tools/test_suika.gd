extends SceneTree

# 作中タイトル「スイカゲーム v2.1」のバグスイッチ（SK-01〜14）が狙いどおり動くかの確認（物理演算も実際に動かす）。
# 実行: godot --headless --path . --script res://tools/test_suika.gd

var failed := 0
var game: SuikaTitle
var checked := []


func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failed += 1


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _initialize() -> void:
	_run.call_deferred()


# バグを指定してプレイし直す（持っている果物は片付けて、盤面を空にする）
func fresh(bugs: Array) -> void:
	checked.clear()
	game.start(bugs)
	await process_frame
	if game.current_fruit:
		game.current_fruit.queue_free()
		game.current_fruit = null
	await physics_frame


func put(rank: int, pos: Vector2) -> SuikaFruit:
	var f := game._make_fruit(rank)
	f.position = pos
	game.fruits.add_child(f)
	return f


func count_rank(rank: int) -> int:
	return game.fruits.get_children().filter(func(f): return not f.is_queued_for_deletion() and f.rank == rank).size()


func click(x: float, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Vector2(x, 300)
	game._on_play_input(e)


func _run() -> void:
	game = load("res://scenes/titles/suika/suika.tscn").instantiate()
	root.add_child(game)
	game.bug_checked.connect(func(id, occurred): checked.append([id, occurred]))
	await process_frame

	# --- バナー（SK-01 / 11 / 12）と最初のタッチ ---
	for case in [[[], game.BANNER_TEXT], [["SK-01"], game.BUG_01_BANNER], [["SK-11"], ""], [["SK-12"], game.BUG_12_BANNER]]:
		await fresh(case[0])
		check(game.banner_label.text == case[1], "バナー %s: 「%s」" % [str(case[0]), case[1]])
	await fresh(["SK-12"])
	click(360, true)
	check(checked.has(["SK-12", true]) and checked.has(["SK-01", false]), "最初に触った時にバナーのバグを見た扱い（ONは見た・OFFは出なかった）")

	# --- SK-08 左に寄せられない / SK-03 右から落ちる ---
	await fresh([])
	var r: float = SuikaFruit.RADII[0]
	check(game._clamp_x(0, r) == game.BIN_LEFT + r and game._clamp_x(999, r) == game.BIN_RIGHT - r, "通常: 左右の壁ぎりぎりまで寄せられる")
	await fresh(["SK-08", "SK-03"])
	check(game._clamp_x(0, r) == game.BIN_LEFT + r + game.BUG_08_LEFT_GAP, "SK-08 ON: 左は壁から離れたところで止まる")
	check(game._clamp_x(999, r) > game.BIN_RIGHT, "SK-03 ON: 右は壁を越えて寄せられる")

	for on in [false, true]:
		await fresh(["SK-03"] if on else [])
		game._spawn_next(true)
		game.aim_x = 999
		await process_frame
		var f := game.current_fruit
		click(999, false)
		check(checked.has(["SK-03", on]), "SK-03 %s: 右端に寄せて落とす操作を検知" % ("ON" if on else "OFF"))
		await wait(2.5)
		var out := not is_instance_valid(f) or f.position.x > game.BIN_RIGHT or f.position.y > game.FLOOR_Y
		check(out == on, "SK-03 %s: 箱の外に落ちた=%s" % ["ON" if on else "OFF", out])

	# --- SK-02 NEXT と違う果物 ---
	for on in [false, true]:
		await fresh(["SK-02"] if on else [])
		game._spawn_next(true)
		await process_frame
		var shown := game.next_rank
		click(360, false)
		await wait(game.COOLDOWN + 0.2)
		check((game.current_fruit.rank != shown) == on, "SK-02 %s: NEXT %d → 出てきた %d" % ["ON" if on else "OFF", shown, game.current_fruit.rank])

	# --- 合体まわり（SK-04 / 13 / 05 / 10） ---
	for on in [false, true]:
		await fresh(["SK-04"] if on else [])
		put(1, Vector2(330, 660)); put(2, Vector2(380, 650))
		await wait(1.0)
		check((count_rank(3) == 1) == on and (count_rank(1) == 0) == on, "SK-04 %s: いちごとぶどうが合体=%s" % ["ON" if on else "OFF", count_rank(3) == 1])

	for on in [false, true]:
		await fresh(["SK-13"] if on else [])
		put(3, Vector2(360, 640)); put(3, Vector2(366, 520))
		await wait(1.0)
		check(count_rank(5 if on else 4) == 1, "SK-13 %s: デコポン同士 → %s" % ["ON" if on else "OFF", "りんご" if on else "かき"])

	for on in [false, true]:
		await fresh(["SK-05"] if on else [])
		put(3, Vector2(360, 640)); put(3, Vector2(366, 520))
		await wait(1.0)
		check(game.score == (50 if on else 100), "SK-05 %s: かきを作った点数 %d" % ["ON" if on else "OFF", game.score])

	for on in [false, true]:
		await fresh(["SK-10"] if on else [])
		put(2, Vector2(360, 660))
		var other := put(0, Vector2(368, 560))
		await wait(1.0)
		check(other.freeze == on, "SK-10 %s: ぶどうに当たった果物がくっついて止まる=%s" % ["ON" if on else "OFF", other.freeze])
		check(checked.has(["SK-10", on]), "SK-10 %s: 操作を検知" % ("ON" if on else "OFF"))

	# --- SK-06 コンボ ---
	for on in [false, true]:
		await fresh(["SK-06"] if on else [])
		var a := put(0, Vector2(200, 600)); var b := put(0, Vector2(200, 600))
		game._resolve_merge(a, b, 1)
		var c := put(0, Vector2(500, 600)); var d := put(0, Vector2(500, 600))
		game._resolve_merge(c, d, 1)
		check(game.score == (20 + 20 if on else 20 + 40), "SK-06 %s: いちご2回（コンボ）で %d 点" % ["ON" if on else "OFF", game.score])

	# --- SK-09 トランポリン ---
	for on in [false, true]:
		await fresh(["SK-09"] if on else [])
		var f := put(2, Vector2(360, 400))
		var top := 999.0
		var landed := false
		for i in 120:
			await physics_frame
			if f.position.y > 600:
				landed = true
			if landed:
				top = minf(top, f.position.y)
		check((top < 560) == on, "SK-09 %s: 底の真ん中で跳ねた高さ y=%d" % ["ON" if on else "OFF", top])

	# --- どんぐり（SK-07 / 14） ---
	for case in [[[], 800, 1], [[], 1200, 2], [["SK-07"], 800, 0], [["SK-07"], 1200, 1], [["SK-14"], 1200, 0]]:
		await fresh(case[0])
		check(game.acorns_for(case[1]) == case[2], "どんぐり %s: %d点 → %d個" % [str(case[0]), case[1], case[2]])
	await fresh(["SK-07"])
	game.score = 800
	game._do_game_over()
	check(game.game_over_panel.visible and game.reward_label.text.ends_with("×0") and checked.has(["SK-07", true]), "500点以上でゲームオーバー → 報酬表示とバグ検知")

	# --- ゲームオーバーの判定（ラインの上で止まっている） ---
	await fresh([])
	var high := put(0, Vector2(360, 60))
	high.freeze = true
	await wait(game.GAME_OVER_DELAY + 0.5)
	check(game.game_over, "ラインの上に1.5秒以上 → ゲームオーバー")

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
