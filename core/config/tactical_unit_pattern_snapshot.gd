extends RefCounted
class_name TacticalUnitPatternSnapshot

## Phase 27B: 不可变战术单位棋路快照
## 由 GameConfig 在 battle start 一次性创建，注入 BattleSystem。
## 拥有纯查询方法：卡牌→棋路 ID、相对移动/攻击偏移、攻击是否位移。
## 行动预算和召唤限制由 MonsterCombatRuleSnapshot 单独负责；本快照不复制这些字段。

const DEFAULT_PATTERN: StringName = &"vanguard"

var default_pattern_id: StringName = DEFAULT_PATTERN
var card_pattern_overrides: Dictionary = {}
var patterns: Dictionary = {}
var used_fallback := false
var validation_errors: Array[String] = []

func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	used_fallback = fallback_used
	validation_errors = errors.duplicate()
	if values.is_empty():
		return
	default_pattern_id = StringName(str(values.get("default_pattern_id", DEFAULT_PATTERN)))
	# 键归一化为 StringName，确保 StringName 查找命中 JSON String 键
	var raw_overrides: Dictionary = values.get("card_pattern_overrides", {})
	card_pattern_overrides = {}
	for key in raw_overrides:
		card_pattern_overrides[StringName(str(key))] = str(raw_overrides[key])
	var raw_patterns: Dictionary = values.get("patterns", {})
	for key in raw_patterns:
		var pat: Dictionary = raw_patterns[key]
		patterns[StringName(str(key))] = {
			"movement_offsets": _to_vector2i_array(pat.get("movement_offsets", [])),
			"attack_offsets": _to_vector2i_array(pat.get("attack_offsets", [])),
			"attack_moves_attacker": bool(pat.get("attack_moves_attacker", false)),
			"ignores_intervening_units": bool(pat.get("ignores_intervening_units", false)),
			"ignores_engagement_for_move": bool(pat.get("ignores_engagement_for_move", false)),
			"raycast_directions": _to_vector2i_array(pat.get("raycast_directions", [])),
		}

static func default_snapshot(errors: Array[String] = []) -> TacticalUnitPatternSnapshot:
	var inst := new()
	inst.used_fallback = true
	inst.validation_errors = errors.duplicate()
	inst.patterns[DEFAULT_PATTERN] = {
		"movement_offsets": [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)],
		"attack_offsets": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)],
		"attack_moves_attacker": false,
	}
	return inst

func to_snapshot() -> Dictionary:
	return {
		"default_pattern_id": default_pattern_id,
		"card_pattern_overrides": card_pattern_overrides.duplicate(true),
		"patterns": _deep_copy_dict(patterns),
		"used_fallback": used_fallback,
	}

## 返回卡牌的棋路 ID；未知卡牌返回 default_pattern_id（先锋）
func get_pattern_id(card_id: StringName) -> StringName:
	if card_pattern_overrides.has(card_id):
		var override: StringName = StringName(str(card_pattern_overrides[card_id]))
		if patterns.has(override):
			return override
	return default_pattern_id

func _resolve_entry(card_id: StringName) -> Dictionary:
	# Phase 27I-R0: 直接按 pattern ID 查询优先（piece_pawn / piece_knight）
	if patterns.has(card_id):
		return patterns[card_id]
	var pid := get_pattern_id(card_id)
	if patterns.has(pid):
		return patterns[pid]
	# 即使未知 pattern ID 也回退到默认先锋
	if patterns.has(DEFAULT_PATTERN):
		return patterns[DEFAULT_PATTERN]
	return {
		"movement_offsets": [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)],
		"attack_offsets": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)],
		"attack_moves_attacker": false,
	}

## 返回复制的移动偏移 Array[Vector2i]
func get_movement_offsets(card_id: StringName = &"") -> Array[Vector2i]:
	var entry: Dictionary = _resolve_entry(card_id)
	var raw: Array = entry.get("movement_offsets", [])
	var out: Array[Vector2i] = []
	for item in raw:
		out.append(item)
	return out

## 返回复制的攻击偏移 Array[Vector2i]
func get_attack_offsets(card_id: StringName = &"") -> Array[Vector2i]:
	var entry: Dictionary = _resolve_entry(card_id)
	var raw: Array = entry.get("attack_offsets", [])
	var out: Array[Vector2i] = []
	for item in raw:
		out.append(item)
	return out

## 攻击是否使攻击者位移
func attack_moves_attacker(card_id: StringName = &"") -> bool:
	return bool(_resolve_entry(card_id).get("attack_moves_attacker", false))

## Phase 27I-R0: 该棋路是否忽略中间单位阻挡（骑士跃迁）
func ignores_intervening_units(pattern_id: StringName) -> bool:
	if patterns.has(pattern_id):
		return bool(patterns[pattern_id].get("ignores_intervening_units", false))
	return false

## Phase 27I-R0: 该棋路移动是否忽略普通牵制
func ignores_engagement_for_move(pattern_id: StringName) -> bool:
	if patterns.has(pattern_id):
		return bool(patterns[pattern_id].get("ignores_engagement_for_move", false))
	return false

## Phase 27I-R1: 返回复制的主教/战车射线方向 Array[Vector2i]
## 纯几何方向，不包含棋盘坐标；未知 pattern 返回空数组。
func get_raycast_directions(pattern_id: StringName) -> Array[Vector2i]:
	var entry: Dictionary = _resolve_entry(pattern_id)
	var raw: Array = entry.get("raycast_directions", [])
	var out: Array[Vector2i] = []
	for item in raw:
		out.append(item)
	return out

# ── 内部工具 ──

func _to_vector2i_array(raw: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if raw is Array:
		for pair in raw:
			if pair is Array and pair.size() == 2:
				result.append(Vector2i(int(pair[0]), int(pair[1])))
	return result

func _deep_copy_dict(src: Dictionary) -> Dictionary:
	var result := {}
	for key in src:
		var val = src[key]
		if val is Dictionary:
			result[key] = _deep_copy_dict(val)
		elif val is Array:
			result[key] = val.duplicate(true)
		else:
			result[key] = val
	return result
