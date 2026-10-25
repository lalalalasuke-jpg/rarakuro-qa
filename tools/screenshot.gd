extends SceneTree
# 見た目確認用: メイン画面を開いてスクショを保存する
# 使い方: godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <出力.png> [faceup|memo|report|confirm|clear|noon|verify|verified|result]
func _initialize() -> void:
	_run.call_deferred()


func submit(main, i: int, overrides := {}) -> void:
	main.game.bug_checked.emit(main.bugs[i].id, true)
	var r: Dictionary = main.bugs[i].report.duplicate()
	r.merge(overrides, true)
	main._on_report_submitted(r)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else ""
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	match mode:
		"faceup":
			for c in main.game.grid.get_children():
				c.flip_up()
		"memo":
			main.memo.show_spec(main.spec)
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
		"result":  # 手順違い1件＋残業ありで1日を終えたところ
			submit(main, 1)
			main.game.bug_checked.emit("MM-HW-002", false)
			submit(main, 0, {"steps": "ゆっくり1枚ずつめくる", "severity": "高"})
			submit(main, 2)
			main.game.bug_checked.emit("MM-HW-003", false)
			submit(main, 0)
			main.game.bug_checked.emit("MM-HW-001", false)
			await create_timer(main.LEADER_DELAY + 0.5).timeout
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
