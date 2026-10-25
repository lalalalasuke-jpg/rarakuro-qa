extends RefCounted

# 仕様メモの絵柄一覧（神経衰弱 v1.4 紅葉狩り）用。秋の絵柄でカードを1枚作る


static func make_icon(index: int, icon_size: float) -> Control:
	return MemoryCard.make_icon(index, icon_size, "autumn")
