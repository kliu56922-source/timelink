extends Node
class_name FieldSystem

var player_field: Array = []
var enemy_field: Array = []

# =========================
# 上场
# =========================
func add_unit_to_player(card: CardData) -> void:
	player_field.append(card)
	print("[FIELD] Player summon: %s" % card.card_name)

func add_unit_to_enemy(card: CardData) -> void:
	enemy_field.append(card)
	print("[FIELD] Enemy summon: %s" % card.card_name)

# =========================
# 移除单位（死亡/效果）
# =========================
func remove_unit_from_player(card: CardData) -> void:
	player_field.erase(card)
	print("[FIELD] Player unit removed: %s" % card.card_name)

func remove_unit_from_enemy(card: CardData) -> void:
	enemy_field.erase(card)
	print("[FIELD] Enemy unit removed: %s" % card.card_name)

# =========================
# 获取场面
# =========================
func get_player_units() -> Array:
	return player_field

func get_enemy_units() -> Array:
	return enemy_field

# =========================
# 清空（调试用）
# =========================
func clear():
	player_field.clear()
	enemy_field.clear()