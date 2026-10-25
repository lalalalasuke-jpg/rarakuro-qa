extends SceneTree
# 見た目確認用: メイン画面を開いてスクショを保存する
# 使い方: godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <出力.png> [faceup|memo|report|clear|noon|result]
func _initialize() -> void:
	_run.call_deferred()
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
		"report":
			main.report_form.open(main.report_options, "神経衰弱 ハロウィンイベント v1.3")
			var g = main.report_form.groups
			for key in ["where", "target"]:
				g[key].get_buttons()[0].button_pressed = true
		"clear":
			main.game._on_clear()
		"noon":  # 朝に正しい報告を出して、昼に開発さんの返事が届いたところ
			main.game.bug_seen.emit("MM-HW-002")
			main._on_report_submitted(main.bugs[1].report)
		"result":  # 手順違い1件＋残業ありで1日を終えたところ
			for i in [1, 0, 2, 0]:
				main.game.bug_seen.emit(main.bugs[i].id)
				var r: Dictionary = main.bugs[i].report.duplicate()
				if main.reports.size() == 1:
					r.steps = "ゆっくり1枚ずつめくる"
					r.severity = "高"
				main._on_report_submitted(r)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
