extends SceneTree
# 見た目確認用: メイン画面を開いて全カードを表にし、スクショを保存する
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	for c in main.game.grid.get_children():
		if c.symbol_index < 8 and c.get_index() < 13:
			c.flip_up()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
