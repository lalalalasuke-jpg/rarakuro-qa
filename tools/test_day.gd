extends SceneTree

# 1日の流れ（朝・昼・夕・残業、返事、修正、結果）を通しで確認する。
# 実行: godot --headless --path . --script res://tools/test_day.gd

var failed := 0


func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failed += 1


func _initialize() -> void:
	_run.call_deferred()


func new_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	return main


# バグを「見た」ことにして、指定の内容で報告を提出する
func submit(main: Node, bug_index: int, overrides := {}) -> void:
	var bug: Dictionary = main.bugs[bug_index]
	main.game.bug_seen.emit(bug.id)
	var report: Dictionary = bug.report.duplicate()
	report.merge(overrides, true)
	main._on_report_submitted(report)


func _run() -> void:
	# --- 返事・修正・残業・結果 ---
	var main = await new_main()
	check(main.day_label.text == "1日目　朝", "朝から始まる")
	submit(main, 1)
	check(main.day_label.text == "1日目　昼", "報告を出すと昼になる")
	check(main.chat_from.text == "開発さん" and main.chat_text.text.contains("修正しました"), "昼の始めに開発さんから「修正しました」")
	check(not main.enabled.has("MM-HW-002"), "002 は昼から直っている")

	submit(main, 0, {"steps": "ゆっくり1枚ずつめくる"})
	check(main.day_label.text == "1日目　夕" and main.chat_text.text.contains("再現しませんでした"), "手順違い → 夕に「再現しませんでした」")
	check(main.enabled.has("MM-HW-001"), "再現しない報告のバグは残る")

	submit(main, 2)
	check(main.day_label.text == "1日目　残業1", "夕方までに全部直らないと残業")
	check(main.no_bug_button.text == "今日はあがる", "残業中は「今日はあがる」")

	main.game.bug_seen.emit("MM-HW-001")
	main._on_report_submitted(main.bugs[1].report)
	check(main.day_label.text == "1日目　残業1" and main.chat_text.text.contains("確認できてない"), "直ったバグ（002）をもう一度報告 → 止められてターンは進まない")

	submit(main, 0)
	check(main.day_result.visible, "全部直ったら1日の結果")
	check(main.reports.size() == 4 and main.fixed.size() == 3, "報告4件・直ったバグ3つ")
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

	# --- 定時で完了 ---
	main = await new_main()
	submit(main, 0)
	submit(main, 1)
	check(not main.day_result.visible, "夕方の報告の返事はまだ")
	submit(main, 2)
	check(main.day_result.visible and main.turn == 2, "3ターンで全部直れば定時で完了")
	main.queue_free()

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
