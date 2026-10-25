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


func new_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	return main


# バグを「見た」ことにして、指定の内容で報告を提出する
func submit(main: Node, bug_index: int, overrides := {}) -> void:
	var bug: Dictionary = main.bugs[bug_index]
	main.game.bug_checked.emit(bug.id, true)
	var report: Dictionary = bug.report.duplicate()
	report.merge(overrides, true)
	main._on_report_submitted(report)


# 修正確認：同じ操作をしてバグが出なかったことにする
func verify(main: Node, bug_index: int) -> void:
	main.game.bug_checked.emit(main.bugs[bug_index].id, false)


func _run() -> void:
	# --- 返事・修正確認・残業・終業前・結果 ---
	var main = await new_main()
	check(main.day_label.text == "1日目　朝", "朝から始まる")
	submit(main, 1)
	check(main.day_label.text == "1日目　昼", "報告を出すと昼になる")
	check(main.chat_from.text == "開発さん" and main.chat_text.text.contains("修正しました"), "昼の始めに開発さんから「修正しました」")
	check(not main.enabled.has("MM-HW-002"), "002 は昼から直っている")
	check(main.report_button.disabled and main.no_bug_button.disabled, "修正確認が終わるまで報告書・異常なしは押せない")
	await create_timer(main.LEADER_DELAY + 0.2).timeout
	check(main.chat_from.text == "リーダー" and main.chat_text.text.contains("確認しよっか"), "少しあとでリーダー「まずは直ってるか確認しよっか」")
	verify(main, 0)
	check(main.verifying.has("MM-HW-002"), "別のバグの操作では修正確認にならない")
	verify(main, 1)
	check(main.verified.has("MM-HW-002") and not main.report_button.disabled, "同じ操作でバグが出ない → 修正確認完了、報告できるように")
	check(main.chat_text.text.contains("ほかに不具合"), "リーダー「ほかに不具合がないか探してみよう」")

	submit(main, 0, {"steps": "ゆっくり1枚ずつめくる"})
	check(main.day_label.text == "1日目　夕" and main.chat_text.text.contains("再現しませんでした"), "手順違い → 夕に「再現しませんでした」")
	check(main.enabled.has("MM-HW-001") and not main.report_button.disabled, "再現しない報告のバグは残る（修正確認なし）")

	submit(main, 2)
	check(main.day_label.text == "1日目　残業1", "夕方までに全部直らないと残業")
	check(main.no_bug_button.text == "今日はあがる" and main.no_bug_button.disabled, "残業中は「今日はあがる」（修正確認中は押せない）")
	verify(main, 2)

	main.game.bug_checked.emit("MM-HW-001", true)
	main._on_report_submitted(main.bugs[1].report)
	check(main.day_label.text == "1日目　残業1" and main.chat_text.text.contains("確認できてない"), "直ったバグ（002）をもう一度報告 → 止められてターンは進まない")

	submit(main, 0)
	check(main.day_label.text == "1日目　終業前" and not main.day_result.visible, "全部直ったら終業前（まだ結果は出ない）")
	check(main.report_button.disabled and main.no_bug_button.disabled, "終業前は修正確認だけ")
	verify(main, 0)
	await create_timer(main.LEADER_DELAY + 0.2).timeout
	check(main.day_result.visible, "最後の修正確認が終わったら1日の結果")
	check(main.reports.size() == 4 and main.fixed.size() == 3 and main.verified.size() == 3, "報告4件・直ったバグ3つ・修正確認3つ")
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

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
