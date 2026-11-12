extends RefCounted
class_name TableLayoutManager

## TableLayoutManager — 牌桌布局管理器 (Phase 4B-6)
## 1600x900 固定布局：Boss区在上，玩家区在下，中央分隔线

const LAYOUT_W := 1600
const LAYOUT_H := 900

# ============================================================
# 1v1 布局：Boss 上半桌，玩家下半桌
# ============================================================
func layout_1v1(player_table: Control, enemy_table: Control) -> void:
	if not player_table or not enemy_table:
		return

	# Boss 牌桌 — 填充 BossArea (BattleTable 内部 10,10 ~ 870,300)
	enemy_table.anchor_left = 0.0
	enemy_table.anchor_top = 0.0
	enemy_table.anchor_right = 1.0
	enemy_table.anchor_bottom = 1.0
	enemy_table.offset_left = 0.0
	enemy_table.offset_top = 0.0
	enemy_table.offset_right = 0.0
	enemy_table.offset_bottom = 0.0

	# 玩家牌桌 — 填充 PlayerArea (BattleTable 内部 10,10 ~ 870,290)
	player_table.anchor_left = 0.0
	player_table.anchor_top = 0.0
	player_table.anchor_right = 1.0
	player_table.anchor_bottom = 1.0
	player_table.offset_left = 0.0
	player_table.offset_top = 0.0
	player_table.offset_right = 0.0
	player_table.offset_bottom = 0.0
