extends SceneTree

# 報告書まわりの確認: 選択肢の作り方、bug_checked、ReportJudge の判定、報告書のページ送り。
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
	var form: Dictionary = load_json("res://data/report_mm_halloween.json")
	var all_ids := bugs.map(func(b): return b.id)

	# --- 選択肢：全バグ候補の正解＋ダミー ---
	var fields := ReportForm.build_fields(form, bugs)
	for b in bugs:
		for f in fields:
			var answers = b.report[f.key]
			if answers is String:
				answers = [answers]
			for a in answers:
				check(f.options.has(a), "%s の正解「%s」が選択肢(%s)にある" % [b.id, a, f.key])
	for f in fields:
		var unique := {}
		for o in f.options:
			unique[o] = true
		check(unique.size() == f.options.size() and f.options.size() >= 3, "%s: 選択肢 %d 個・重複なし" % [f.key, f.options.size()])

	# --- 報告書のページ送り ---
	var rf: ReportForm = load("res://scenes/office/report_form.tscn").instantiate()
	root.add_child(rf)
	rf.open(form, bugs, "test")
	check(rf.page == 0 and rf.next_button.disabled, "1ページ目は選ぶまで「次へ」が押せない")
	check(rf.options_box.get_child_count() == fields[0].options.size(), "1ページ目には「どこで」の選択肢だけ")
	var got := [{}]
	rf.submitted.connect(func(r): got[0] = r)
	for i in fields.size():
		rf.selections[fields[i].key] = fields[i].options[0]
		rf._go(rf.page)
		check(not rf.next_button.disabled, "%d ページ目: 選んだら「次へ」" % (i + 1))
		rf._on_next()
	check(rf.page == fields.size() and rf.next_button.text == "提出する", "最後は確認ページ")
	rf._on_next()
	check(got[0].size() == fields.size(), "確認ページから提出できる")
	rf.clear()
	check(rf.page == 0 and rf.selections.is_empty(), "clear で最初に戻る")
	rf.queue_free()

	# --- bug_checked ---
	var game: MemoryMatch = load("res://scenes/titles/memory_match/memory_match.tscn").instantiate()
	root.add_child(game)
	var seen := []
	game.bug_checked.connect(func(id, occurred): seen.append([id, occurred]))
	game.start(all_ids)
	await process_frame
	check(not seen.has(["MM-HW-005", true]), "005: 開いただけではまだ「見た」にしない")
	var cards := game.grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	var candy: MemoryCard = cards.filter(func(c): return c.symbol_index == MemoryMatch.BUG_001_SYMBOL)[0]
	game._on_card_pressed(candy)
	check(seen.has(["MM-HW-005", true]), "005: 最初にカードを触った時にバナーのバグを見た扱い")
	check(seen.has(["MM-HW-001", true]), "001: キャンディをめくると見える")
	game._on_clear()
	check(seen.has(["MM-HW-003", true]), "003: 報酬×1のクリア画面で見える")
	await create_timer(1.0).timeout
	seen.clear()
	game.start([])
	await process_frame
	cards = game.grid.get_children().filter(func(c): return not c.is_queued_for_deletion())
	candy = cards.filter(func(c): return c.symbol_index == MemoryMatch.BUG_001_SYMBOL)[0]
	game._on_card_pressed(candy)
	game._on_clear()
	check(seen.has(["MM-HW-001", false]) and seen.has(["MM-HW-003", false]) and seen.has(["MM-HW-005", false]),
		"バグOFFで同じ操作 → 出なかった（修正確認に使う）")
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
	not_bug.actual = "カードがめくれない"
	j = ReportJudge.judge(not_bug, bugs, all_ids, ["MM-HW-002"], [])
	check(j.result == ReportJudge.BY_DESIGN, "どのバグとも合わない → 仕様です")

	j = ReportJudge.judge(perfect, bugs, ["MM-HW-001"], [], [])
	check(j.result == ReportJudge.NOT_SEEN, "修正済み・その日に起きないバグ → 見ていない扱いで止める")

	j = ReportJudge.judge(perfect, bugs, all_ids, ["MM-HW-002"], ["MM-HW-002"])
	check(j.result == ReportJudge.DUPLICATE, "報告済み → 重複です")

	var sev := perfect.duplicate()
	sev.severity = "低"
	sev.where = "クリア画面"
	j = ReportJudge.judge(sev, bugs, all_ids, ["MM-HW-002"], [])
	check(j.result == ReportJudge.FIX and j.severity == "near" and not j.checks.where, "重要度1段ずれ → near、どこで× でも修正します")

	# --- 手順が大事でないバグ・重要度の正解が複数・採点 ---
	var b1: Dictionary = bugs[0]
	var r1: Dictionary = b1.report.duplicate()
	r1.severity = "中"
	r1.steps = "ゆっくり1枚ずつめくる"
	j = ReportJudge.judge(r1, bugs, all_ids, ["MM-HW-001"], [])
	check(j.result == ReportJudge.FIX and not j.checks.steps and j.severity == "exact", "001: 手順違いでも修正、重要度「中」も正解")
	check(ReportJudge.score(j) == 80, "001 手順違い → 80点（実際 %d）" % ReportJudge.score(j))
	j = ReportJudge.judge(perfect, bugs, all_ids, ["MM-HW-002"], [])
	check(ReportJudge.score(j) == 100, "全部正しい → 100点")
	j = ReportJudge.judge(sev, bugs, all_ids, ["MM-HW-002"], [])
	check(ReportJudge.score(j) == 85, "どこで× 重要度△ → 85点（実際 %d）" % ReportJudge.score(j))
	j = ReportJudge.judge(wrong_steps, bugs, all_ids, ["MM-HW-002"], [])
	check(ReportJudge.score(j) == ReportJudge.MISS_PENALTY, "再現しません → 減点")
	check(ReportJudge.rank(270, 300) == "S" and ReportJudge.rank(230, 300) == "A" and ReportJudge.rank(100, 300) == "C", "ランク")

	print("RESULT: %s" % ("ALL OK" if failed == 0 else "%d FAILED" % failed))
	quit(1 if failed else 0)
