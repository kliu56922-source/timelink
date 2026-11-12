extends Node
class_name CardCatalogLoader

## CardCatalogLoader — Phase 5C-1: 从 JSON 读取原始卡牌 Dictionary
## 5C-2 将接入 convert_to_carddata() 完成 CardData 实例化
## 加载失败不崩，返回空数组 + warning

const JSON_PATH := "res://data/cards/player_cards_20.json"
const ARSENAL_JSON_PATH := "res://data/cards/arsenal_cards_6.json"  # Phase 13C

## Optional fixed-path experiment. Default load_player_cards remains unchanged.
func load_player_pack(pack_id: StringName) -> Array[CardData]:
	if pack_id not in [&"phase_f1", &"phase_f2"]:
		return []
	var path := "res://data/cards/phase_f1_player_cards.json" if pack_id == &"phase_f1" else "res://data/cards/phase_f2_player_cards.json"
	if not FileAccess.file_exists(path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return []
	return convert_player_pack(parser.data) if pack_id == &"phase_f1" else convert_terrain_raise_pack(parser.data)

## Validate the entire pack before allocating any CardData/effect Nodes.
func convert_player_pack(table: Variant) -> Array[CardData]:
	return _convert_experimental_pack(table, false)

func convert_terrain_raise_pack(table: Variant) -> Array[CardData]:
	return _convert_experimental_pack(table, true)

func _convert_experimental_pack(table: Variant, terrain_raise: bool) -> Array[CardData]:
	if not table is Dictionary or table.size() != 2 or not _pack_integer(table.get("schema_version"), 1):
		return []
	var cards: Variant = table.get("cards")
	if not cards is Array or cards.size() != 1 or not cards[0] is Dictionary:
		return []
	var card: Dictionary = cards[0]
	var expected := {"id": "P22", "card_type": "SPELL", "archetype_role": "CONTROL",
		"rarity": "COMMON", "board_zone": "INSTANT", "display_type": "NONE", "require_awaken": false,
		"route_id": "control_route", "next_cards": ["Chain Breaker"], "effect_ids": ["structure_repair"]}
	if terrain_raise:
		expected.merge({"id": "P23", "archetype_role": "STARTER", "route_id": "heat_route", "next_cards": ["Ignite Blade", "Heat Channeler"], "effect_ids": ["terrain_raise"]}, true)
	var effect_id := "terrain_raise" if terrain_raise else "structure_repair"
	for key in expected:
		if typeof(card.get(key)) != typeof(expected[key]) or card.get(key) != expected[key]:
			return []
	for key in ["cn_name", "en_name", "short_description_cn"]:
		if not card.get(key) is String or str(card[key]).strip_edges().is_empty():
			return []
	var numbers := {"od_cost": 0, "load_cost": 1, "require_od": 0, "require_load": 0, "engine_gain": 0, "route_step": 2}
	if terrain_raise:
		numbers.engine_gain = 1
		numbers.route_step = 1
	for key in numbers:
		if not _pack_integer(card.get(key), numbers[key]):
			return []
	var effects: Variant = card.get("effect_values")
	if not effects is Dictionary or effects.size() != 1 or not _pack_integer(effects.get(effect_id), 1):
		return []
	# Optional metadata is text-only. Unexpected behavior-bearing fields fail closed.
	var allowed: Array = expected.keys() + numbers.keys() + ["effect_values", "cn_name", "en_name", "short_description_cn", "full_description_cn", "layer_1_2_text", "layer_3_4_text", "layer_5_text", "art_key"]
	for key in card:
		if key not in allowed:
			return []
		if key not in expected and key not in numbers and key != "effect_values" and not card[key] is String:
			return []
	var normalized := card.duplicate(true)
	for key in numbers:
		normalized[key] = numbers[key]
	normalized.effect_values = {effect_id: 1}
	var result: Array[CardData] = [convert_to_carddata(normalized)]
	return result

static func _pack_integer(value: Variant, expected: int) -> bool:
	return (value is int and value == expected) or (value is float and is_finite(value) and value == float(expected))

## Phase 13C: Arsenal 卡片缓存
var arsenal_cards: Array[CardData] = []


## 加载原始卡牌 Dictionary 列表（5C-1 主入口）
## 返回 Array[Dictionary]
func load_raw_cards() -> Array:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("[CardCatalog] Cannot open %s — returning empty." % JSON_PATH)
		return _empty_result("File not found: " + JSON_PATH)

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[CardCatalog] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return _empty_result("Parse error")

	var data: Variant = json.get_data()
	if data == null or not data is Dictionary:
		push_warning("[CardCatalog] JSON root is not a Dictionary.")
		return _empty_result("Invalid root type")

	var cards: Array = data.get("cards", [])
	if cards.is_empty():
		push_warning("[CardCatalog] JSON 'cards' array is empty.")
		return _empty_result("Empty cards array")

	# 校验每张卡的必要字段
	var valid_count := 0
	for i in range(cards.size()):
		var card: Variant = cards[i]
		if not card is Dictionary:
			push_warning("[CardCatalog] Entry %d is not a Dictionary — skipped." % i)
			continue
		if not card.has("id") or not card.has("en_name"):
			push_warning("[CardCatalog] Entry %d missing id or en_name — skipped." % i)
			continue
		valid_count += 1

	print("[CardCatalog] Loaded raw cards: %d/%d" % [valid_count, cards.size()])
	return cards


## 5C-2: 加载并转换为 CardData 实例（主入口）
func load_player_cards() -> Array:
	var raw := load_raw_cards()
	if raw.is_empty():
		return []
	var result: Array = []
	for card_dict in raw:
		if not card_dict is Dictionary:
			continue
		var cd := convert_to_carddata(card_dict)
		if cd != null:
			result.append(cd)
	print("[CardCatalog] Converted %d/%d cards to CardData." % [result.size(), raw.size()])
	return result


# ============================================================
# Phase 13C: OD Arsenal 加载
# ============================================================

## 加载 Arsenal 原始卡牌 Dictionary 列表
func load_raw_arsenal_cards() -> Array:
	var file := FileAccess.open(ARSENAL_JSON_PATH, FileAccess.READ)
	if file == null:
		push_warning("[CardCatalog] Arsenal JSON not found: %s — skipping." % ARSENAL_JSON_PATH)
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[CardCatalog] Arsenal JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return []

	var data: Variant = json.get_data()
	if data == null or not data is Dictionary:
		push_warning("[CardCatalog] Arsenal JSON root is not a Dictionary.")
		return []

	var cards: Array = data.get("cards", [])
	if cards.is_empty():
		push_warning("[CardCatalog] Arsenal JSON 'cards' array is empty.")
		return []

	var valid_count := 0
	for i in range(cards.size()):
		var card: Variant = cards[i]
		if not card is Dictionary:
			push_warning("[CardCatalog] Arsenal entry %d is not a Dictionary — skipped." % i)
			continue
		if not card.has("id") or not card.has("en_name"):
			push_warning("[CardCatalog] Arsenal entry %d missing id or en_name — skipped." % i)
			continue
		valid_count += 1

	print("[CardCatalog] Arsenal raw cards loaded: %d/%d" % [valid_count, cards.size()])
	return cards


## 加载 Arsenal 卡并转换为 CardData 实例
func load_arsenal_cards() -> void:
	arsenal_cards.clear()
	var raw := load_raw_arsenal_cards()
	if raw.is_empty():
		return

	var result: Array[CardData] = []
	for card_dict in raw:
		if not card_dict is Dictionary:
			continue
		var cd := convert_arsenal_to_carddata(card_dict)
		if cd != null:
			result.append(cd)

	arsenal_cards = result
	print("[CardCatalog] Arsenal loaded: %d/%d" % [arsenal_cards.size(), raw.size()])


## 将 Arsenal JSON Dictionary 转换为 CardData（复用 convert_to_carddata + Arsenal 字段）
func convert_arsenal_to_carddata(card_dict: Dictionary) -> CardData:
	var card := convert_to_carddata(card_dict)

	# ── Phase 13C: Arsenal 专用字段 ──
	card.is_arsenal_card = card_dict.get("is_arsenal_card", true)
	card.arsenal_tier = card_dict.get("arsenal_tier", "")
	card.unlock_layer = card_dict.get("unlock_layer", 0)
	card.usage_stage = card_dict.get("usage_stage", "")
	card.arsenal_usage_limit = card_dict.get("arsenal_usage_limit", 1)
	card.enters_graveyard = card_dict.get("enters_graveyard", true)
	card.requires_mid_arsenal_used = card_dict.get("requires_mid_arsenal_used", false)

	# ── Phase 13F-1: 升格字段 ──
	card.is_ascension_form = card_dict.get("is_ascension_form", false)
	card.ascension_layer = card_dict.get("ascension_layer", 0)
	card.ascension_cost_type = card_dict.get("ascension_cost_type", "")
	card.ascension_material_count = card_dict.get("ascension_material_count", 1)
	card.ascension_replaces_source = card_dict.get("ascension_replaces_source", true)
	card.ascension_text_cn = card_dict.get("ascension_text_cn", "")
	card.ascension_depth_min = card_dict.get("ascension_depth_min", 0)
	card.ascension_material_series_id = card_dict.get("ascension_material_series_id", "")
	# 安全读取字符串数组
	var asc_from: Array = card_dict.get("ascends_from_ids", [])
	for aid in asc_from:
		if aid is String and aid != "":
			card.ascends_from_ids.append(aid)

	# ── 确保 Arsenal 卡不参与主卡组路线 ──
	card.route_id = ""
	card.route_step = 0
	card.next_cards.clear()

	return card


## 公开访问器：获取全部 Arsenal 卡
func get_arsenal_cards() -> Array[CardData]:
	return arsenal_cards


## 公开访问器：按 ID 查找 Arsenal 卡
func get_arsenal_card_by_id(id: String) -> CardData:
	for card in arsenal_cards:
		if card.card_id == id:
			return card
	return null


## 将单条 Dictionary 转换为 CardData
## 当前仅供文档/骨架参考，5C-2 正式接入时启用
func convert_to_carddata(card_dict: Dictionary) -> CardData:
	var card := CardData.new()

	# ── 身份 ──
	card.card_name = card_dict.get("en_name", "")
	card.card_id = card_dict.get("id", "")
	card.display_name = card_dict.get("cn_name", "")
	card.english_name = card_dict.get("en_name", "")

	# ── 类型映射 ──
	var raw_card_type: String = card_dict.get("card_type", "SPELL")
	card.card_type = _map_card_type(raw_card_type)
	card.card_family = _map_card_family(raw_card_type)
	card.rarity = _map_rarity(card_dict.get("rarity", "COMMON"))
	card.archetype_role = _map_role(card_dict.get("archetype_role", "STARTER"))

	# ── Phase 27I-R0: 固定棋子身份 ──
	card.piece_type = StringName(str(card_dict.get("piece_type", "")))
	card.piece_enabled = bool(card_dict.get("piece_enabled", false))
	card.piece_effect_profile_id = StringName(str(card_dict.get("piece_effect_profile_id", "")))
	card.piece_payload_id = StringName(str(card_dict.get("piece_payload_id", "")))

	# ── 牌桌归属 ──
	card.board_zone = _map_board_zone(card_dict.get("board_zone", "INSTANT"))
	card.display_type = _map_display_type(card_dict.get("display_type", "NONE"))
	card.is_continuous = card.card_family == "building" or card.display_type == CardData.DisplayType.SUSTAIN

	# ── 费用 ──
	card.od_cost = card_dict.get("od_cost", 0)
	card.load_cost = card_dict.get("load_cost", 1)
	card.require_od = card_dict.get("require_od", 0)
	card.require_load = card_dict.get("require_load", 0)
	card.require_hp_cost = maxi(0, int(card_dict.get("require_hp_cost", 0)))
	card.is_guard_card = bool(card_dict.get("is_guard_card", false))
	card.require_awaken = card_dict.get("require_awaken", false)

	# ── 单位属性 ──
	card.unit_power = card_dict.get("unit_power", 0)
	card.unit_defense = card_dict.get("unit_defense", 0)
	if card.unit_power > 0 or card.unit_defense > 0:
		card.unit_description = "ATK:%d DEF:%d" % [card.unit_power, card.unit_defense]

	# ── Route ──
	card.route_id = card_dict.get("route_id", "")
	card.route_step = card_dict.get("route_step", 0)
	var next_raw: Array = card_dict.get("next_cards", [])
	for nc in next_raw:
		if nc is String and nc != "":
			card.next_cards.append(nc)

	# ── 关键词 + 标签 ──
	var kws: Array = card_dict.get("keywords", [])
	for kw in kws:
		if kw is String and kw != "":
			card.keywords.append(kw)

	# ── 文本 ──
	card.short_description = card_dict.get("short_description_cn", "")
	card.description = card_dict.get("full_description_cn", "")
	card.calm_text = card_dict.get("calm_text", "")
	card.heated_text = card_dict.get("heated_text", "")
	card.overdrive_text = card_dict.get("overdrive_text", "")
	card.flavor_text = card_dict.get("flavor_text_cn", "")
	card.od_interface_text = card_dict.get("od_interface_text", "")
	card.building_charge_text = card_dict.get("building_charge_text", "")
	card.building_resonance_text = card_dict.get("building_resonance_text", "")

	# ── Effects（5C-2 接入映射函数）──
	_build_effects(card, card_dict.get("effect_ids", []), card_dict.get("effect_values", {}))

	# ── Phase 5D-2: 小轴元数据 ──
	card.series_id = card_dict.get("series_id", "generic")
	var sec_ids: Array = card_dict.get("secondary_series_ids", [])
	for sid in sec_ids:
		if sid is String and sid != "":
			card.secondary_series_ids.append(sid)
	var stags: Array = card_dict.get("search_tags", [])
	for stag in stags:
		if stag is String and stag != "":
			card.search_tags.append(stag)
	var rcards: Array = card_dict.get("related_cards", [])
	for rc in rcards:
		if rc is String and rc != "":
			card.related_cards.append(rc)
	card.building_tier = card_dict.get("building_tier", -1)
	card.building_unique = card_dict.get("building_unique", false)
	card.entry_condition_type = card_dict.get("entry_condition_type", "")
	card.entry_condition_value = card_dict.get("entry_condition_value", 0)
	card.entry_condition_text_cn = card_dict.get("entry_condition_text_cn", "")
	# ── Phase 7A-5: OD 五层引擎字段 ──
	card.engine_gain = card_dict.get("engine_gain", -999)
	card.layer_1_2_text = card_dict.get("layer_1_2_text", "")
	card.layer_3_4_text = card_dict.get("layer_3_4_text", "")
	card.layer_5_text = card_dict.get("layer_5_text", "")

	# ── Phase 6A: Tutor 检索字段 ──
	card.tutor_enabled = card_dict.get("tutor_enabled", false)
	card.tutor_timing = card_dict.get("tutor_timing", "")
	card.tutor_series_id = card_dict.get("tutor_series_id", "")
	card.tutor_card_type = card_dict.get("tutor_card_type", "")
	card.tutor_tag = card_dict.get("tutor_tag", "")
	card.tutor_count = card_dict.get("tutor_count", 1)
	card.tutor_text_cn = card_dict.get("tutor_text_cn", "")

	# ── 美术 ──
	card.art_id = card_dict.get("art_key", "")
	card.art_path = "res://assets/cards/thumbs/card_%s_%s.png" % [card.card_id.to_lower(), card.art_id]
	# Phase 7E-1: 显式设置 thumb_path 和 detail_path
	card.thumb_path = "res://assets/cards/thumbs/card_%s_%s.png" % [card.card_id.to_lower(), card.art_id]
	card.detail_path = "res://assets/cards/detail/card_%s_%s.png" % [card.card_id.to_lower(), card.art_id]

	# ── Legacy ──
	var legacy: Array = card_dict.get("legacy_names", [])
	for ln in legacy:
		if ln is String and ln != "" and not ln in card.legacy_names:
			card.legacy_names.append(ln)
	if not card.card_name in card.legacy_names:
		card.legacy_names.append(card.card_name)

	return card


## 枚举映射
func _map_card_type(ct: String) -> int:
	match ct:
		"SPELL": return 0
		"MONSTER": return 1
		"FUSION": return 1   # Phase 13C: FUSION 按 MONSTER 处理
		"COUNTER", "TRAP": return 2
		"BUILD": return 2
	return 0


func _map_card_family(ct: String) -> String:
	match ct:
		"MONSTER": return "monster"
		"SPELL": return "spell"
		"COUNTER", "TRAP": return "counter"
		"BUILD": return "building"
	return "spell"


func _map_rarity(r: String) -> int:
	match r:
		"COMMON": return 0
		"RARE": return 1
		"SUPER": return 2
	return 0


func _map_role(r: String) -> int:
	match r:
		"STARTER": return 0
		"EXTENDER": return 1
		"CONTROL": return 2
		"FINISHER": return 3
		"DEFENSE": return 4
	return 0


func _map_board_zone(bz: String) -> int:
	match bz:
		"FRONT_ROW": return 0
		"BACK_ROW": return 1
		"INSTANT": return 2
	return 2


func _map_display_type(dt: String) -> int:
	match dt:
		"UNIT": return CardData.DisplayType.UNIT
		"TRAP": return CardData.DisplayType.TRAP
		"SUSTAIN": return CardData.DisplayType.SUSTAIN
		"NONE": return CardData.DisplayType.NONE
	return CardData.DisplayType.NONE


## 5C-2 骨架：根据 effect_ids + effect_values 构建 Effect 对象
func _build_effects(card: CardData, ids: Array, values: Dictionary) -> void:
	card.effects.clear()
	for eff_id in ids:
		var amount: int = values.get(eff_id, 0)
		var eff = _create_effect(eff_id, amount)
		if eff != null:
			card.effects.append(eff)
		else:
			push_warning("[CardCatalog] Unknown effect_id '%s' for card %s — skipped." % [eff_id, card.card_id])


func _create_effect(eff_id: String, amount: int):
	var path: String = ""
	match eff_id:
		"terrain_raise": path = "res://core/effect/terrain_raise_effect.gd"
		"structure_repair": path = "res://core/effect/structure_repair_effect.gd"
		"draw":           path = "res://core/effect/draw_effect.gd"
		"damage":         path = "res://core/effect/damage_effect.gd"
		"shield":         path = "res://core/effect/shield_effect.gd"
		"self_od":        path = "res://core/effect/od_effect.gd"
		"enemy_od":       path = "res://core/effect/enemy_od_effect.gd"
		"self_damage":    path = "res://core/effect/self_damage_effect.gd"
		"conditional_damage": path = "res://core/effect/conditional_damage_effect.gd"
		_: return null

	var cls = load(path)
	if cls == null:
		return null
	var eff = cls.new()
	match eff_id:
		"terrain_raise": eff.set("amount", amount)
		"structure_repair": eff.set("amount", amount)
		"draw":           eff.set("amount", amount)
		"damage":         eff.set("base_damage", amount)
		"shield":         eff.set("amount", amount)
		"self_od":        eff.set("amount", amount)
		"enemy_od":       eff.set("amount", amount)
		"self_damage":    eff.set("amount", amount)
		"conditional_damage": eff.set("base_damage", amount)
	return eff


func _empty_result(reason: String) -> Array:
	print("[CardCatalog] Load failed: %s" % reason)
	return []


func _build_combo_hint(route_id: String, route_step: int) -> String:
	if route_id == "":
		return ""
	match route_id:
		"heat_route":
			match route_step:
				1: return "Heat Route 起点"
				2: return "Heat Route Step2"
				3: return "Heat Route Step3"
				4: return "Heat Route 终点"
		"overdrive_route":
			match route_step:
				1: return "Overdrive Route 起点"
				2: return "Overdrive Route Step2"
				3: return "Overdrive Route Step3"
				4: return "Overdrive Route 终点"
		"control_route":
			match route_step:
				1: return "Control Route 起点"
				2: return "Control Route Step2"
				3: return "Control Route 终点"
	return ""


func _auto_color_theme(card_type: String, role: int) -> String:
	if role == 3: return "red"
	match card_type:
		"MONSTER": return "orange"
		"SPELL": return "blue"
		"COUNTER": return "blue"
		"BUILD": return "orange"
	return "blue"
