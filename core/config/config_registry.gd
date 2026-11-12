extends RefCounted
class_name ConfigRegistry

## Phase 25A: 配置表统一加载器
## 加载 JSON 配置表，提供按表名读取的稳定入口。
## 从不崩溃于缺失文件；收集所有错误。

static var _tables: Dictionary = {}
static var _loaded: bool = false
static var _errors: Array[String] = []
static var _siege_load_errors: Array[String] = []

# 表定义: { logical_name, file_path }
const TABLE_DEFS := [
	{ "name": "battle_rules",    "path": "res://data/config/battle_rules.json" },
	{ "name": "od_depth_rules",  "path": "res://data/config/od_depth_rules.json" },
	{ "name": "encounter",       "path": "res://data/encounters/forge_guard_demo.json" },
	{ "name": "boss_deck",       "path": "res://data/boss_decks/forge_guard_deck.json" },
	{ "name": "localization",          "path": "res://data/localization/zh_cn.json" },
	{ "name": "monster_combat_rules",  "path": "res://data/config/monster_combat_rules.json" },
		{ "name": "combat_presentation",   "path": "res://data/config/combat_presentation.json" },
		{ "name": "od_core_commands",      "path": "res://data/config/od_core_commands.json" },
		{ "name": "od_companion_presentation", "path": "res://data/config/od_companion_presentation.json" },
		{ "name": "tactical_grid_rules", "path": "res://data/config/tactical_grid_rules.json" },
		{ "name": "tactical_grid_presentation", "path": "res://data/config/tactical_grid_presentation.json" },
	{ "name": "tactical_unit_patterns", "path": "res://data/config/tactical_unit_patterns.json" },
	{ "name": "tactical_core_facing_rules",  "path": "res://data/config/tactical_core_facing_rules.json" },
	{ "name": "tactical_command_economy",  "path": "res://data/config/tactical_command_economy.json" },
	{ "name": "monster_hero_skills",  "path": "res://data/config/monster_hero_skills.json" },  # Phase 27E
	{ "name": "boss_tactical_ai",  "path": "res://data/config/boss_tactical_ai_rules.json" },  # Phase 27F
	{ "name": "card_piece_traits", "path": "res://data/config/card_piece_traits.json" },  # Phase 27I-R0
	{ "name": "od_release_rules", "path": "res://data/config/od_release_rules.json" },  # Phase 27J
	{ "name": "od_presentation_rules", "path": "res://data/config/od_presentation_rules.json" },  # Phase 27K-R0
	{ "name": "od_flow_feedback_rules", "path": "res://data/config/od_flow_feedback_rules.json" },  # Phase 27K-R1-A
	{ "name": "tactical_structure_rules", "path": "res://data/config/tactical_structure_rules.json" },  # Phase C
	{ "name": "tactical_structure_presentation", "path": "res://data/config/tactical_structure_presentation.json" },  # Phase C presentation
	{ "name": "tactical_garrison_rules", "path": "res://data/config/tactical_garrison_rules.json" },  # Phase D1
	{ "name": "tactical_siege_rules", "path": "res://data/config/tactical_siege_rules.json" },  # Phase E (isolated optional table)
]


static func load_all() -> bool:
	_tables.clear()
	_errors.clear()
	_siege_load_errors.clear()
	_loaded = false

	for defn: Dictionary in TABLE_DEFS:
		var name: String = defn["name"]
		var path: String = defn["path"]
		if name == "tactical_siege_rules":
			_load_siege_table(path)
			continue
		if not FileAccess.file_exists(path):
			_errors.append("[CONFIG ERROR] File not found: %s (%s)" % [name, path])
			print_rich("[color=red][CONFIG ERROR][/color] File not found: %s (%s)" % [name, path])
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_errors.append("[CONFIG ERROR] Cannot open: %s (%s)" % [name, path])
			print_rich("[color=red][CONFIG ERROR][/color] Cannot open: %s (%s)" % [name, path])
			continue
		var text := file.get_as_text()
		file.close()
		var json := JSON.new()
		var err := json.parse(text)
		if err != OK:
			var msg := "[CONFIG ERROR] JSON parse failed in %s: %s (line %d)" % [name, json.get_error_message(), json.get_error_line()]
			_errors.append(msg)
			print_rich("[color=red]%s[/color]" % msg)
			continue
		var data = json.get_data()
		if not data is Dictionary:
			var msg := "[CONFIG ERROR] %s root is not a Dictionary" % name
			_errors.append(msg)
			print_rich("[color=red]%s[/color]" % msg)
			continue
		_tables[name] = data
		print_rich("[color=cyan][CONFIG][/color] %s OK" % path)

	_loaded = true
	if _errors.is_empty():
		print_rich("[color=green][CONFIG][/color] All %d tables loaded, 0 errors" % _tables.size())
	else:
		print_rich("[color=yellow][CONFIG][/color] %d tables loaded, %d errors" % [_tables.size(), _errors.size()])
	return _errors.is_empty()


static func get_table(name: String) -> Dictionary:
	if not _tables.has(name):
		return {}
	return _tables[name]


## 用 "." 分隔的路径从表中取值，如 "depth.max" → 6
static func get_value(table_name: String, path: String, fallback = null):
	var table: Dictionary = get_table(table_name)
	if table.is_empty():
		return fallback
	var keys := path.split(".")
	var current = table
	for i in range(keys.size()):
		var key: String = keys[i]
		if not current is Dictionary or not current.has(key):
			return fallback
		if i == keys.size() - 1:
			return current[key]
		current = current[key]
	return fallback


static func is_loaded() -> bool:
	return _loaded


static func get_errors() -> Array[String]:
	return _errors.duplicate()


## Optional E diagnostics are consumed/reported by its factory, never old factories.
static func get_tactical_siege_load_errors() -> Array[String]:
	return _siege_load_errors.duplicate()


static func _load_siege_table(path: String) -> void:
	_tables.erase("tactical_siege_rules")
	_siege_load_errors.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_siege_load_errors.append("[tactical_siege_rules] cannot open: %s" % path)
		return
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		_siege_load_errors.append("[tactical_siege_rules] invalid JSON at line %d" % json.get_error_line())
		return
	if not json.data is Dictionary:
		_siege_load_errors.append("[tactical_siege_rules] root must be Dictionary")
		return
	_tables["tactical_siege_rules"] = json.data


static func has_table(name: String) -> bool:
	return _tables.has(name)
