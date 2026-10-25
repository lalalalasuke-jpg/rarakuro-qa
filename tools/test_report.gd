extends SceneTree

# 報告書まわりの確認: バグが画面に出た時の bug_seen、ReportJudge の判定、選択肢と正解の文言のズレ。
# 実行: godot --headless --path . --script res://tools/test_report.gd

var failed := 0


func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failed += 1


func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bugs: Array = load_json("res://data/bugs.json").bugs
	var options: Dictionary = load_json("res://data/report_mm_halloween.json")
	var all_ids := bugs.map(func(b): return b.id)

	# --- 正解の文言が選択肢に必ずある（データの書き間違い防止） ---
	for b in bugs:
		for field in options.fields:
			check(field.options.has(b.report[field.key]), "%s の正解「%s」が選択肢(%s)にある" % [b.id, b.report[field.key], field.key])

	# --- bug_seen ---
	var game: MemoryMatch = load("res://scenes/titles/memory_match/memory_match.tscn").instantiate()
	root.add_child(game)
	var seen := []
	game.bug_seen.connect(func(id): seen.append(id))
	game.start(all_ids)
	var cards := game.grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	var normal: MemoryCard = cards.filter(func(c): return not c.halloween)[0]
	game._on_card_pressed(normal)
	check(seen.has("MM-HW-001"), "001: 通常絵柄のカードをめくると bug_seen")
	var others := cards.filter(func(c): return c.halloween and c.symbol_index != cards.filter(func(x): return x.halloween)[0].symbol_index)
	var first_h = cards.filter(func(x): return x.halloween)[0]
	game._on_card_pressed(first_h)
	game._on_card_pressed(others[0])
	check(seen.has("MM-HW-002"), "002: 3枚目が表になると bug_seen")
	await create_timer(1.5).timeout
	game._on_clear()
	check(seen.has("MM-HW-003"), "003: 報酬×1のクリア画面で bug_seen")
	seen.clear()
	game.start([])
	game._on_clear()
	check(seen.is_empty(), "バグOFFなら bug_seen は出ない")
	game.queue_free()

	# --- ReportJudge ---
	var b2: Dictionary = bugs[1]
	var perfect: Dictionary = b2.report.duplicate()
	var j := ReportJudge.judge(perfect, bugs, all_ids, ["MM-HW-002"], [])
	check(j.result == ReportJudge.FIX and j.checks.values().all(func(v): return v) and j.severity == "exact", "全部正しい → 修正します")

	j = ReportJudge.judge(perfect, bugs, all_ids, [], [])
	check(j.result == ReportJudge.NOT_SEEN, "見ていないバグ → 止める")

	var wrong_steps := perfect.duplicate()
	wrong_steps.steps = "ゆっくり1枚ずつめくる"
	j = ReportJudge.judge(wrong_steps, bugs, all_ids, ["MM-HW-002"], [])
	check(j.result == ReportJudge.CANNOT_REPRODUCE, "再現手順が違う → 再現しません")

	var not_bug := perfect.duplicate()
	not_bug.actual = "違う絵柄なのにペアになる"
	j = ReportJudge.judge(not_bug, bugs, all_ids, ["MM-HW-002"], [])
	check(j.result == ReportJudge.BY_DESIGN, "どのバグとも合わない → 仕様です")

	j = ReportJudge.judge(perfect, bugs, ["MM-HW-001"], ["MM-HW-002"], [])
	check(j.result == ReportJudge.BY_DESIGN, "仕込んでいないバグ → 仕様です")

	j = ReportJudge.judge(perfect, bugs, all_ids, ["MM-HW-002"], ["MM-HW-002"])
	check(j.result == ReportJudge.DUPLICATE, "報告済み → 重複です")

	var sev := perfect.duplicate()
	sev.severity = "低"
	sev.where = "クリア画面"
	j = ReportJudge.judge(sev, bugs, all_ids, ["MM-HW-002"], [])
	check(j.result == ReportJudge.FIX and j.severity == "near" and not j.checks.where, "重要度1段ずれ → near、どこで× でも修正します")

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
