class_name ReportJudge
extends RefCounted

# 報告書の判定。画面を持たない計算だけの部品なので、テストから直接呼べる。
# 「実際の動き」でどのバグの報告かを決め、残りの項目を正解（data/bugs.json の report）と比べる。

# 判定の結果（result）
const NOT_SEEN := "not_seen"          # まだ画面で見ていないバグ → 提出前にリーダーが止める
const FIX := "fix"                    # 修正します
const CANNOT_REPRODUCE := "cannot_reproduce"  # 再現しません（再現手順が違う）
const BY_DESIGN := "by_design"        # 仕様です（どのバグとも合わない）
const DUPLICATE := "duplicate"        # 重複です（同じバグを報告済み）

const SEVERITY_ORDER := ["低", "中", "高"]
const CHECK_KEYS := ["where", "steps", "target", "expected"]


# report: 項目キー→選んだ文言。bugs: bugs.json の bugs。
# enabled: 今仕込まれているバグ ID。observed: プレイヤーが画面で見たバグ ID。reported: 報告済みのバグ ID
static func judge(report: Dictionary, bugs: Array, enabled: Array, observed: Array, reported: Array) -> Dictionary:
	var bug: Dictionary = {}
	for b in bugs:
		if b.report.actual == report.get("actual"):
			bug = b
			break
	# 修正済み・仕込んでいないバグは画面に出ないので、ここで「見ていない」になる
	if not bug.is_empty() and not observed.has(bug.id):
		return {"result": NOT_SEEN, "bug_id": bug.id}
	if bug.is_empty() or not enabled.has(bug.id):
		return {"result": BY_DESIGN, "bug_id": ""}
	if reported.has(bug.id):
		return {"result": DUPLICATE, "bug_id": bug.id}

	var checks := {}
	for key in CHECK_KEYS:
		checks[key] = report.get(key) == bug.report[key]
	var diff := absi(SEVERITY_ORDER.find(report.get("severity")) - SEVERITY_ORDER.find(bug.report.severity))
	var severity := "exact" if diff == 0 else ("near" if diff == 1 else "off")
	return {
		"result": FIX if checks.steps else CANNOT_REPRODUCE,
		"bug_id": bug.id,
		"checks": checks,
		"severity": severity,
	}


# 開発からの返答の見出し
static func result_text(result: String) -> String:
	match result:
		FIX: return "修正します"
		CANNOT_REPRODUCE: return "再現しません"
		BY_DESIGN: return "仕様です"
		DUPLICATE: return "重複です"
		NOT_SEEN: return "（未確認）"
	return result


# 開発さんからの返事（次のターンの始めにチャットで届く）
static func dev_reply(report: Dictionary, judge: Dictionary) -> String:
	var subject := "「%s」の件" % report.get("actual", "")
	match judge.result:
		FIX: return "%s、修正しました！修正版をもう入れてあります。" % subject
		CANNOT_REPRODUCE: return "%s、書いてある手順だと再現しませんでした…。手順をもう一度確認してもらえますか？" % subject
		BY_DESIGN: return "%s、確認しましたが仕様どおりの動きです。" % subject
		DUPLICATE: return "%sは、もう報告をもらっています。" % subject
	return ""
