extends "res://scenes/experiments/gb1_integrated_battle.gd"
## GB-2B: 独立 Boss 压力卡池实验入口。
## 继承 GB1 的启动预检、固定 16 张牌、真实六张起手、seed 2701、E/F1/F2、进度隔离与失败启动保护。
## 本包只额外做两件事：从本包独立 JSON 读取并校验 Boss 卡池、在当前 BossCardDeck 实例上局部启用。
## 不写全局 Registry/GameCfg，不改默认池，不新增资格或结算算法。

const GB2B_ENTRY_PATH := "res://scenes/experiments/gb2b_integrated_battle.tscn"
const GB2B_DECK_PATH := "res://data/experiments/gb2b_boss_deck.json"
const GB2B_DECK_ID := "gb2b_forge_guard_deck"

## 冻结首版数据：数组顺序也是复现合同。校验以此为准，不一致即启动失败，绝不 fallback。
const GB2B_FROZEN_TABLE := {
	"schema_version": 1,
	"deck_id": "gb2b_forge_guard_deck",
	"pools": {
		"Calm": [
			{"card_id": "B-07", "weight": 1},
		],
		"Heated": [
			{"card_id": "B-03", "weight": 2},
			{"card_id": "B-04", "weight": 2},
			{"card_id": "B-07", "weight": 4},
			{"card_id": "B-09", "weight": 1},
			{"card_id": "B-18", "weight": 2},
		],
		"Overdrive": [
			{"card_id": "B-07", "weight": 2},
			{"card_id": "B-15", "weight": 3},
			{"card_id": "B-16", "weight": 2},
			{"card_id": "B-18", "weight": 1},
		],
	},
}

const GB2B_ZONES: Array[String] = ["Calm", "Heated", "Overdrive"]

## 预检通过后的本包配置缓存（深副本）；_setup_game 只消费它。
var _gb2b_deck_config: Dictionary = {}


# ============================================================
# Task 1：父初始化之前的配置预检
# ============================================================
## 覆写点：测试用局部子类可返回空文本 / 坏 JSON 以验证失败路径，不改磁盘上的生产 JSON。
func _read_gb2b_deck_text() -> String:
	if not FileAccess.file_exists(GB2B_DECK_PATH):
		return ""
	return FileAccess.get_file_as_string(GB2B_DECK_PATH)


## 只追加本包配置错误到父级 problems；不重写 _ready / _gb1_prepare_startup。
func _load_gb1_rule_snapshots(problems: Array[String]) -> Dictionary:
	var rules: Dictionary = super._load_gb1_rule_snapshots(problems)
	_gb2b_deck_config = {}
	var table: Dictionary = _validate_gb2b_deck_text(_read_gb2b_deck_text(), problems)
	if table.is_empty():
		return rules
	_gb2b_deck_config = table.duplicate(true)
	return rules


## 校验并返回规范化后的深副本；任何不一致写入 problems 并返回空字典。
func _validate_gb2b_deck_text(text: String, problems: Array[String]) -> Dictionary:
	var errors: Array[String] = []
	var table: Dictionary = _parse_gb2b_deck(text, errors)
	problems.append_array(errors)
	return table


func _parse_gb2b_deck(text: String, errors: Array[String]) -> Dictionary:
	if text.strip_edges().is_empty():
		errors.append("gb2b boss deck unreadable: %s" % GB2B_DECK_PATH)
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		errors.append("gb2b boss deck is not valid JSON: %s" % GB2B_DECK_PATH)
		return {}
	if not parser.data is Dictionary:
		errors.append("gb2b boss deck is not a JSON object: %s" % GB2B_DECK_PATH)
		return {}
	var raw: Dictionary = parser.data

	for key in raw:
		if not key is String or not ["schema_version", "deck_id", "pools"].has(key):
			errors.append("gb2b boss deck has unknown top-level field: %s" % str(key))
	if not _gb2b_positive_int_equals(raw.get("schema_version"), 1):
		errors.append("gb2b boss deck schema_version must be 1, got %s" % str(raw.get("schema_version")))
	if str(raw.get("deck_id", "")) != GB2B_DECK_ID:
		errors.append("gb2b boss deck deck_id must be %s, got %s" % [GB2B_DECK_ID, str(raw.get("deck_id", ""))])
	if not raw.get("pools") is Dictionary:
		errors.append("gb2b boss deck pools must be a Dictionary")
		return {}
	var pools: Dictionary = raw.pools
	for key in pools:
		if not key is String or not GB2B_ZONES.has(key):
			errors.append("gb2b boss deck has unknown pool: %s" % str(key))
	if pools.size() != GB2B_ZONES.size():
		errors.append("gb2b boss deck must have exactly %d pools, got %d" % [GB2B_ZONES.size(), pools.size()])

	var normalized: Dictionary = {}
	for zone in GB2B_ZONES:
		var entries: Variant = pools.get(zone)
		if not entries is Array:
			errors.append("gb2b boss deck pool %s missing or not an Array" % zone)
			continue
		var raw_entries: Array = entries
		if raw_entries.is_empty():
			errors.append("gb2b boss deck pool %s is empty" % zone)
			continue
		var seen: Dictionary = {}
		var normalized_entries: Array = []
		for i in raw_entries.size():
			var entry: Variant = raw_entries[i]
			if not entry is Dictionary:
				errors.append("gb2b boss deck %s[%d] is not a Dictionary" % [zone, i])
				continue
			var entry_dict: Dictionary = entry
			for key in entry_dict:
				if not key is String or not ["card_id", "weight"].has(key):
					errors.append("gb2b boss deck %s[%d] has unknown field: %s" % [zone, i, str(key)])
			var card_id := str(entry_dict.get("card_id", "")).strip_edges()
			if card_id.is_empty():
				errors.append("gb2b boss deck %s[%d] card_id is empty" % [zone, i])
				continue
			if seen.has(card_id):
				errors.append("gb2b boss deck pool %s has duplicate card_id: %s" % [zone, card_id])
				continue
			var weight: Variant = entry_dict.get("weight")
			if not _gb2b_positive_int(weight):
				errors.append("gb2b boss deck %s[%d] weight must be a positive integer, got %s" % [zone, i, str(weight)])
				continue
			seen[card_id] = true
			normalized_entries.append({"card_id": card_id, "weight": int(weight)})
		normalized[zone] = normalized_entries

	if not errors.is_empty():
		return {}
	_check_gb2b_frozen_table(normalized, errors)
	if not errors.is_empty():
		return {}
	return {"schema_version": 1, "deck_id": GB2B_DECK_ID, "pools": normalized}


## ID / 权重 / 顺序必须与本版冻结表逐项一致。
func _check_gb2b_frozen_table(normalized: Dictionary, errors: Array[String]) -> void:
	var frozen_pools: Dictionary = GB2B_FROZEN_TABLE.get("pools", {})
	for zone in GB2B_ZONES:
		var expected: Array = frozen_pools.get(zone, [])
		var actual: Array = normalized.get(zone, [])
		if expected.size() != actual.size():
			errors.append("gb2b boss deck %s must have %d entries, got %d" % [zone, expected.size(), actual.size()])
			continue
		for i in expected.size():
			var want: Dictionary = expected[i]
			var got: Dictionary = actual[i]
			if str(got.get("card_id", "")) != str(want.card_id) or int(got.get("weight", 0)) != int(want.weight):
				errors.append("gb2b boss deck %s[%d] must be %s:%d, got %s:%d"
					% [zone, i, str(want.card_id), int(want.weight), str(got.get("card_id", "")), int(got.get("weight", 0))])


## 正整数判定：接受 JSON 的有限整数浮点表示，拒绝布尔 / 字符串 / 0 / 负数 / 非整数。
func _gb2b_positive_int(value: Variant) -> bool:
	if value is bool or value is String:
		return false
	if value is int:
		return value > 0
	if value is float:
		return is_finite(value) and value == floor(value) and value > 0.0
	return false


func _gb2b_positive_int_equals(value: Variant, expected: int) -> bool:
	if value is bool or value is String:
		return false
	if value is int:
		return value == expected
	if value is float:
		return is_finite(value) and value == float(expected)
	return false


# ============================================================
# Task 2：局部启用（父初始化权威建立同一个 boss_deck 之后再接线）
# ============================================================
func _setup_game() -> void:
	super._setup_game()
	# 同一 boss_deck 实例：只启用实验牌、打开地形威胁、装上本包已校验的卡池副本。
	# 不再 setup、不重建 BossCardDeck、不重置 RNG、不重复连接信号。
	boss_deck.enable_terrain_threat_experiment()
	battle.configure_boss_terrain_threat(true)
	boss_deck.configure_deck(_gb2b_deck_config.duplicate(true))
	print("[GB-2B] experimental boss deck applied: %s" % GB2B_DECK_ID)


## 只负责重新加载 GB2B 入口；加载失败时解除重入锁并恢复按钮，明确报告，不切回 GB1。
func restart_gb1_battle() -> void:
	if _gb1_restarting:
		return
	_gb1_restarting = true
	if _gb1_restart_button != null and is_instance_valid(_gb1_restart_button):
		_gb1_restart_button.disabled = true
	var err := get_tree().change_scene_to_file(GB2B_ENTRY_PATH)
	if err != OK:
		_gb1_restarting = false
		if _gb1_restart_button != null and is_instance_valid(_gb1_restart_button):
			_gb1_restart_button.disabled = false
		push_error("[GB-2B] restart failed to load %s (err=%d)" % [GB2B_ENTRY_PATH, err])
