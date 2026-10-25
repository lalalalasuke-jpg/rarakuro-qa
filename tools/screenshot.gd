extends SceneTree
# 見た目確認用: メイン画面を開いてスクショを保存する
# 使い方: godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <出力.png> [faceup|memo|report|confirm|clear|noon|verify|verified|result]
func _initialize() -> void:
	_run.call_deferred()


func submit(main, i: int, overrides := {}) -> void:
	main.game.bug_checked.emit(main.bugs[i].id, true)
	var r: Dictionary = main.bugs[i].report.duplicate()
	if r.severity is Array:
		r.severity = r.severity[0]
	r.merge(overrides, true)
	main._on_report_submitted(r)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else ""
	# 「d2_◯◯」は2日目（スイカゲーム）で ◯◯ のモード
	var day := 2 if mode.begins_with("d2") else 1
	mode = mode.trim_prefix("d2").trim_prefix("_")
	OfficeMain.next_day = day
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	# 本番はランダム。スクショは固定
	main.setup_bugs(["MM-HW-001", "MM-HW-002", "MM-HW-003"] if day == 1 else ["SK-12", "SK-04", "SK-07"])
	match mode:
		"play":  # スイカゲームを少し自動で遊んだところ
			for x in [200, 330, 470, 260, 400, 520, 300, 440]:
				main.game.aim_x = x
				await create_timer(0.1).timeout
				main.game._drop()
				await create_timer(main.game.COOLDOWN + 0.1).timeout
			await create_timer(1.0).timeout
		"gameover":
			main.game.score = 820
			main.game._do_game_over()
		"faceup":
			for c in main.game.grid.get_children():
				c.flip_up()
		"memo":
			main.memo.show_spec(main.spec)
		"memo_end":  # 仕様メモを一番下までスクロールしたところ
			main.memo.show_spec(main.spec)
			await create_timer(0.3).timeout
			main.memo.scroll.scroll_vertical = 99999
		"report":  # 報告書の1ページ目（どこで）
			main.report_button.emit_signal("pressed")
		"confirm":  # 報告書の確認ページ
			main.report_button.emit_signal("pressed")
			for f in main.report_form.fields:
				main.report_form.selections[f.key] = main.bugs[1].report[f.key]
			main.report_form._go(main.report_form.fields.size())
		"clear":
			main.game._on_clear()
		"noon":  # 朝に正しい報告を出して、昼に開発さんの返事が届いたところ
			submit(main, 1)
		"verify":  # 返事のあと、リーダーが修正確認を頼んだところ
			submit(main, 1)
			await create_timer(main.LEADER_DELAY + 0.2).timeout
		"verified":  # 修正確認が済んだ瞬間
			submit(main, 1)
			await create_timer(main.LEADER_DELAY + 0.2).timeout
			main.game.bug_checked.emit("MM-HW-002", false)
		"result":  # 手順違い（でも直してもらえた）1件ありで、定時に1日を終えたところ
			submit(main, 1)
			main.game.bug_checked.emit("MM-HW-002", false)
			submit(main, 0, {"steps": "ゆっくり1枚ずつめくる", "severity": "高"})
			main.game.bug_checked.emit("MM-HW-001", false)
			submit(main, 2)
			main.game.bug_checked.emit("MM-HW-003", false)
			await create_timer(main.LEADER_DELAY + 0.5).timeout
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
