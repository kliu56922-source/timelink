extends Node
class_name GraveyardSystem

var player_graveyard: Array = []
var enemy_graveyard: Array = []

# =========================
# 添加
# =========================
func add_to_player_graveyard(card: CardData) -> void:
	player_graveyard.append(card)
	print("[GRAVE] Player -> %s" % card.card_name)

func add_to_enemy_graveyard(card: CardData) -> void:
	enemy_graveyard.append(card)
	print("[GRAVE] Enemy -> %s" % card.card_name)

# =========================
# 查询
# =========================
func get_player_graveyard_count() -> int:
	return player_graveyard.size()

func get_enemy_graveyard_count() -> int:
	return enemy_graveyard.size()

func get_player_graveyard() -> Array:
	return player_graveyard

# =========================
# 移除（复活/回收）
# =========================
func remove_from_player_graveyard(card: CardData) -> void:
	player_graveyard.erase(card)

# =========================
# 随机取（未来玩法）
# =========================
func get_random_from_player() -> CardData:
	if player_graveyard.is_empty():
		return null
	return player_graveyard.pick_random()

# =========================
# 清空
# =========================
func clear():
	player_graveyard.clear()
	enemy_graveyard.clear()