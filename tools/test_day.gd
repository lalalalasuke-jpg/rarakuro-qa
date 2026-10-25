extends SceneTree

# 1日の流れ（朝・昼・夕・残業・終業前、返事、修正確認、結果）を通しで確認する。
# 実行: godot --headless --path . --script res://tools/test_day.gd

var failed := 0


func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failed += 1


func _initialize() -> void:
	_run.call_deferred()


# テストではその日のバグを 001〜003 に固定する（本番はランダム）
func new_main() -> Node:
	OfficeMain.next_day = 1
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.setup_bugs(["MM-HW-001", "MM-HW-002", "MM-HW-003"])
	return main


# バグを「見た」ことにして、指定の内容で報告を提出する
func submit(main: Node, bug_index: int, overrides := {}) -> void:
	var bug: Dictionary = main.bugs[bug_index]
	main.game.bug_checked.emit(bug.id, true)
	var report: Dictionary = bug.report.duplicate()
	if report.severity is Array:  # 正解が複数のときは1つ目を選ぶ
		report.severity = report.severity[0]
	report.merge(overrides, true)
	main._on_report_submitted(report)


# 修正確認：同じ操作をしてバグが出なかったことにする
func verify(main: Node, bug_index: int) -> void:
	main.game.bug_checked.emit(main.bugs[bug_index].id, false)


func _run() -> void:
	# --- 毎回ランダムに3つ選ばれる ---
	var picks := {}
	for i in 6:
		var m = load("res://scenes/main.tscn").instantiate()
		root.add_child(m)
		await process_frame
		check(m.day_bugs.size() == 3 and m.enabled.size() == 3, "ランダムで3つ選ばれる: %s" % str(m.enabled))
		picks[str(m.enabled)] = true
		m.queue_free()
	check(picks.size() > 1, "遊ぶたびに違う組み合わせになる（6回で %d 通り）" % picks.size())

	# --- 返事・修正確認・残業・終業前・結果 ---
	var main = await new_main()
	check(main.day_label.text == "1日目　朝", "朝から始まる")
	submit(main, 0, {"steps": "ゆっくり1枚ずつめくる"})
	check(main.day_label.text == "1日目　昼", "報告を出すと昼になる")
	check(main.chat_from.text == "開発さん" and main.chat_text.text.contains("手順は少し違ったけど"), "手順が大事でない001は手順違いでも修正してもらえる")
	check(not main.enabled.has("MM-HW-001"), "001 は昼から直っている")
	check(main.report_button.disabled and main.no_bug_button.disabled, "修正確認が終わるまで報告書・異常なしは押せない")
	await create_timer(main.LEADER_DELAY + 0.2).timeout
	check(main.chat_from.text == "リーダー" and main.chat_text.text.contains("「カードを1枚めくる」"), "リーダーは正しい手順で確認を頼む")
	verify(main, 1)
	check(main.verifying.has("MM-HW-001"), "別のバグの操作では修正確認にならない")
	verify(main, 0)
	check(main.verified.has("MM-HW-001") and not main.report_button.disabled, "同じ操作でバグが出ない → 修正確認完了、報告できるように")
	check(main.chat_text.text.contains("ほかに不具合"), "リーダー「ほかに不具合がないか探してみよう」")

	submit(main, 1, {"steps": "ゆっくり1枚ずつめくる"})
	check(main.day_label.text == "1日目　夕" and main.chat_text.text.contains("再現しませんでした"), "手順が大事な002の手順違い → 夕に「再現しませんでした」")
	check(main.enabled.has("MM-HW-002") and not main.report_button.disabled, "再現しない報告のバグは残る（修正確認なし）")

	submit(main, 2)
	check(main.day_label.text == "1日目　残業1", "夕方までに全部直らないと残業")
	check(main.no_bug_button.text == "今日はあがる" and main.no_bug_button.disabled, "残業中は「今日はあがる」（修正確認中は押せない）")
	verify(main, 2)

	main.game.bug_checked.emit("MM-HW-002", true)
	main._on_report_submitted(main.bugs[0].report)
	check(main.day_label.text == "1日目　残業1" and main.chat_text.text.contains("確認できてない"), "直ったバグ（001）をもう一度報告 → 止められてターンは進まない")

	submit(main, 1)
	check(main.day_label.text == "1日目　終業前" and not main.day_result.visible, "全部直ったら終業前（まだ結果は出ない）")
	check(main.report_button.disabled and main.no_bug_button.disabled, "終業前は修正確認だけ")
	verify(main, 1)
	await create_timer(main.LEADER_DELAY + 0.2).timeout
	check(main.day_result.visible, "最後の修正確認が終わったら1日の結果")
	check(main.reports.size() == 4 and main.fixed.size() == 3 and main.verified.size() == 3, "報告4件・直ったバグ3つ・修正確認3つ")
	# 80（001 手順違い）−10（002 再現しません）+100（003）+100（002）−10（残業1）= 260
	check(DayResult.total_score(main.reports, 1) == 260, "スコア 260（実際 %d）" % DayResult.total_score(main.reports, 1))
	main.queue_free()

	# --- 異常なしと「今日はあがる」 ---
	main = await new_main()
	main._on_no_bug_pressed()
	main._on_no_bug_pressed()
	check(main.day_label.text == "1日目　夕" and main.chat_from.text == "リーダー", "異常なしでもターンが進む（返事なし→リーダー）")
	main._on_no_bug_pressed()
	check(main.day_label.text == "1日目　残業1", "夕方の異常なし → 残業")
	main._on_no_bug_pressed()
	check(main.day_result.visible and main.fixed.is_empty(), "今日はあがる → 結果（見逃し3つ）")
	main.queue_free()

	# --- 定時で完了（終業前で最後の確認） ---
	main = await new_main()
	submit(main, 0)
	verify(main, 0)
	submit(main, 1)
	verify(main, 1)
	submit(main, 2)
	check(main.day_label.text == "1日目　終業前" and main.turn == 2, "3ターンで全部直れば終業前")
	verify(main, 2)
	await create_timer(main.LEADER_DELAY + 0.2).timeout
	check(main.day_result.visible, "終業前の修正確認 → 結果")
	main.queue_free()

	# --- 起きないバグ（004〜007）は1日目には報告できない ---
	main = await new_main()
	main._on_report_submitted(main.bugs[3].report)
	check(main.day_label.text == "1日目　朝" and main.chat_text.text.contains("確認できてない"), "1日目に起きないバグを報告 → 止められる")
	main.queue_free()

	# --- 1日目の結果から2日目へ ---
	main = await new_main()
	main._on_no_bug_pressed(); main._on_no_bug_pressed(); main._on_no_bug_pressed(); main._on_no_bug_pressed()
	check(main.day_result.next_button.text == "2日目へ" and not main.day_result.next_button.disabled, "1日目の結果に「2日目へ」")
	main.queue_free()

	# --- 2日目：スイカゲーム ---
	OfficeMain.next_day = 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.day_no == 2 and main.game is SuikaTitle, "2日目の担当はスイカゲーム")
	check(main.bugs.size() == 14 and main.bugs.all(func(b): return b.id.begins_with("SK-")), "バグ候補はスイカの14個だけ")
	check(main.day_label.text == "2日目　朝" and main.chat_text.text.contains("スイカゲーム"), "ヘッダーとリーダーのチャット")
	check(main.enabled.size() == 3, "ランダムで3つ: %s" % str(main.enabled))

	# 同じ group（同じ場所）のバグは重ならない
	var overlap := 0
	for i in 200:
		var ids := OfficeMain.pick_bugs(main.bugs, 3)
		var groups := {}
		for id in ids:
			var g: String = main._bug(id).get("group", "")
			if g != "":
				if groups.has(g):
					overlap += 1
				groups[g] = true
	check(overlap == 0, "200回選んでも、バナー・どんぐりのバグは同じ日に重ならない")

	# モニターの中の小さな画面（SubViewport）にタップが届く
	var pos: Vector2 = main.game.touch_area.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)
		await process_frame
	# headless（画面なし）ではタップの処理が動かないので、ウィンドウありで実行した時だけ確かめる
	if DisplayServer.get_name() == "headless":
		print("SKIP モニターの中のスイカゲームにタップが届く（ウィンドウありで実行すると確認できる）")
	else:
		check(main.game.touched, "モニターの中のスイカゲームにタップが届く")

	# 報告 → 返事 → 修正確認 → 終業前 → 結果
	main.setup_bugs(["SK-01", "SK-04", "SK-07"])
	var sk := func(id): return main.bugs.filter(func(b): return b.id == id)[0]
	for id in ["SK-01", "SK-04", "SK-07"]:
		main.game.bug_checked.emit(id, true)
		var r: Dictionary = sk.call(id).report.duplicate()
		if r.severity is Array:
			r.severity = r.severity[0]
		main._on_report_submitted(r)
		check(main.chat_text.text.contains("修正しました"), "%s: 修正しました" % id)
		main.game.bug_checked.emit(id, false)
	check(main.day_label.text == "2日目　終業前", "3つとも直って終業前")
	await create_timer(main.LEADER_DELAY + 0.3).timeout
	check(main.day_result.visible and DayResult.total_score(main.reports, 0) == 300, "2日目の結果 300点")
	check(not main.day_result.next_button.disabled and main.day_result.next_button.text == "3日目へ", "2日目の結果に「3日目へ」")
	main.queue_free()

	# --- 3日目：神経衰弱 v1.4 紅葉狩り ---
	OfficeMain.next_day = 3
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.day_no == 3 and main.game is MemoryMatch and main.game.edition == "autumn", "3日目は神経衰弱 v1.4（紅葉狩り）")
	check(main.bugs.size() == 11 and main.bugs.all(func(b): return b.id.begins_with("MM-AU-")), "バグ候補は紅葉狩りの11個だけ")
	check(main.chat_text.text.contains("v1.4") and main.spec.has("release_notes"), "リーダーのチャットと、仕様メモのリリースノート")
	main.setup_bugs(["MM-AU-01", "MM-AU-06", "MM-AU-08"])
	var au := func(id): return main.bugs.filter(func(b): return b.id == id)[0]
	for id in ["MM-AU-01", "MM-AU-06", "MM-AU-08"]:
		main.game.bug_checked.emit(id, true)
		var r: Dictionary = au.call(id).report.duplicate()
		if r.severity is Array:
			r.severity = r.severity[0]
		main._on_report_submitted(r)
		check(main.chat_text.text.contains("修正しました"), "%s: 修正しました" % id)
		main.game.bug_checked.emit(id, false)
	await create_timer(main.LEADER_DELAY + 0.3).timeout
	check(main.day_result.visible and DayResult.total_score(main.reports, 0) == 300, "3日目の結果 300点")
	check(main.day_result.next_button.disabled and main.day_result.next_button.text == "4日目へ（準備中）", "3日目の結果は「4日目へ（準備中）」")
	main.queue_free()

	# 進んだ日の保存
	OfficeMain.save_progress(2)
	check(OfficeMain.load_progress() == 2, "進んだ日が保存される")
	OfficeMain.save_progress(1)

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
