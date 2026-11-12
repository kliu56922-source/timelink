extends Node

# ===== GameManager — 全局单例 =====
# 负责：场景切换、当前卡组、玩家数据、牌桌配置、存档

const SAVE_PATH := "user://save_data.json"

var current_deck: DeckData
var current_player_data: Dictionary = {}

# ===== 玩家主页显示 =====
var player_name: String = "Player"
var current_deck_name: String = "Overheat Combo"

# ===== 牌桌配置（TableConfig 对象）=====
var current_table_config: TableConfig


# 持久化的 CardLibrary（防止 CardData 节点提前释放）
var _persistent_library: CardLibrary = null
var _loaded_deck_cards: Array[CardData] = []

func _ready():
	current_deck = DeckData.new()
	current_player_data = {
		"wins": 0,
		"losses": 0,
		"highest_combo": 0,
		"awakenings_triggered": 0,
	}
	current_table_config = TableConfig.new()
	_ensure_library()
	load_game()


## 确保 CardLibrary 始终存活（CardData extends Node，需要父节点保持引用）
func _ensure_library() -> void:
	if _persistent_library == null or not is_instance_valid(_persistent_library):
		_persistent_library = CardLibrary.new()
		add_child(_persistent_library)


## 获取当前 CardLibrary 引用（供其他场景使用）
func get_library() -> CardLibrary:
	_ensure_library()
	return _persistent_library


# =========================
# 场景切换
# =========================
func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


# =========================
# 卡组存取
# =========================
func set_deck(deck: DeckData) -> void:
	current_deck = deck
	if deck.deck_name != "":
		current_deck_name = deck.deck_name
	save_game()


func get_deck() -> DeckData:
	return current_deck


func get_deck_cards() -> Array:
	return current_deck.cards if current_deck else []


# =========================
# 牌桌配置存取
# =========================
func get_table_config() -> TableConfig:
	return current_table_config


func set_table_skin(id: String) -> void:
	current_table_config.table_skin_id = id
	save_game()


func set_od_core_skin(id: String) -> void:
	current_table_config.od_core_skin_id = id
	save_game()


func set_card_back(id: String) -> void:
	current_table_config.card_back_id = id
	save_game()


func set_graveyard_skin(id: String) -> void:
	current_table_config.graveyard_skin_id = id
	save_game()


# =========================
# 玩家数据
# =========================
func record_win() -> void:
	current_player_data["wins"] += 1
	save_game()


func record_loss() -> void:
	current_player_data["losses"] += 1
	save_game()


func record_combo(count: int) -> void:
	if count > current_player_data["highest_combo"]:
		current_player_data["highest_combo"] = count
		save_game()


func record_awakening() -> void:
	current_player_data["awakenings_triggered"] += 1
	save_game()


# =========================
# 存档系统
# =========================
func save_game() -> void:
	var data := {
		"player_name": player_name,
		"current_deck_name": current_deck_name,
		"deck_cards": _deck_to_names(),
		"table_skin_id": current_table_config.table_skin_id,
		"od_core_skin_id": current_table_config.od_core_skin_id,
		"card_back_id": current_table_config.card_back_id,
		"graveyard_skin_id": current_table_config.graveyard_skin_id,
		"wins": current_player_data.get("wins", 0),
		"losses": current_player_data.get("losses", 0),
		"highest_combo": current_player_data.get("highest_combo", 0),
		"awakenings_triggered": current_player_data.get("awakenings_triggered", 0),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("[GameManager] Failed to open save file for writing: %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[GameManager] Game saved (%d cards in deck)." % data["deck_cards"].size())


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[GameManager] No save file found — starting fresh.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("[GameManager] Failed to open save file for reading.")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		print("[GameManager] Failed to parse save file: %s" % json.get_error_message())
		return

	var data = json.get_data()
	if data == null or not data is Dictionary:
		print("[GameManager] Save data is not a dictionary.")
		return

	# 恢复基础数据
	player_name = data.get("player_name", "Player")
	current_deck_name = data.get("current_deck_name", "Overheat Combo")

	# 恢复牌桌配置
	current_table_config.table_skin_id = data.get("table_skin_id", "default_dark")
	current_table_config.od_core_skin_id = data.get("od_core_skin_id", "default_core")
	current_table_config.card_back_id = data.get("card_back_id", "default")
	current_table_config.graveyard_skin_id = data.get("graveyard_skin_id", "default")

	# 恢复卡组
	var card_names: Array = data.get("deck_cards", [])
	if card_names.size() > 0:
		_rebuild_deck_from_names(card_names)

	# 恢复统计数据
	current_player_data["wins"] = data.get("wins", 0)
	current_player_data["losses"] = data.get("losses", 0)
	current_player_data["highest_combo"] = data.get("highest_combo", 0)
	current_player_data["awakenings_triggered"] = data.get("awakenings_triggered", 0)

	print("[GameManager] Game loaded: %s | Deck: %s (%d cards) | W:%d L:%d" % [
		player_name, current_deck_name, card_names.size(),
		current_player_data["wins"], current_player_data["losses"]
	])


# =========================
# 存档辅助
# =========================
func _deck_to_names() -> Array:
	var names: Array = []
	for card in current_deck.cards:
		if card and "card_name" in card:
			names.append(card.card_name)
	return names


func _rebuild_deck_from_names(card_names: Array) -> void:
	_ensure_library()

	for owned in _loaded_deck_cards:
		if is_instance_valid(owned) and owned.get_parent() == self:
			owned.free()
	_loaded_deck_cards.clear()
	current_deck = DeckData.new()
	var resolved_count := 0
	var legacy_count := 0
	for card_name in card_names:
		var found := false
		# 首先按精确 internal name 查找，克隆独立实体
		for card in _persistent_library.all_cards:
			if card.card_name == card_name:
				var cloned := CardData.clone_card_entity(card)
				if cloned != null:
					add_child(cloned)
					_loaded_deck_cards.append(cloned)
					current_deck.add_card(cloned)
					found = true
					resolved_count += 1
				break
		# 如果没找到，通过 legacy_names 兼容旧存档
		if not found:
			for card in _persistent_library.all_cards:
				if card.has_method("matches_name") and card.matches_name(card_name):
					var cloned := CardData.clone_card_entity(card)
					if cloned != null:
						add_child(cloned)
						_loaded_deck_cards.append(cloned)
						current_deck.add_card(cloned)
						found = true
						legacy_count += 1
						print("[GameManager] Legacy card '%s' → '%s'" % [card_name, card.card_name])
					break
		if not found:
			print("[GameManager] Card '%s' not found in library — skipped." % card_name)

	print("[GameManager] Deck rebuilt from %d names → %d cards (exact: %d, legacy: %d)" % [card_names.size(), current_deck.cards.size(), resolved_count, legacy_count])
