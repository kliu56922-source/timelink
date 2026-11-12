extends RefCounted
class_name BattleRuleSnapshot

## Phase 25B: 每场战斗只读 OD/Depth 规则快照
## 由 GameConfig.create_battle_rule_snapshot() 构造，创建后不可变。

# ── 私有字段 ──
var _od_max: int
var _calm_min: int
var _calm_max: int
var _heated_min: int
var _heated_max: int
var _overdrive_min: int
var _overdrive_max: int
var _depth_max: int
var _depth_end_turn_recover: int
var _depth_backlash_threshold: int
var _depth_control_reduce: int
var _stable_od_first_unit_damage: int
var _stable_od_first_enemy_destroyed: int
var _stable_od_player_turn_cap: int
var _stable_od_boss_turn_core_damage_comeback: int
var _used_fallback: bool
var _validation_errors: Array[String]

# ── 只读属性 ──
var od_max: int:
	get:
		return _od_max

var depth_max: int:
	get:
		return _depth_max

var depth_end_turn_recover: int:
	get:
		return _depth_end_turn_recover

var depth_backlash_threshold: int:
	get:
		return _depth_backlash_threshold

var depth_control_reduce: int:
	get:
		return _depth_control_reduce

var stable_od_first_unit_damage: int:
	get:
		return _stable_od_first_unit_damage

var stable_od_first_enemy_destroyed: int:
	get:
		return _stable_od_first_enemy_destroyed

var stable_od_player_turn_cap: int:
	get:
		return _stable_od_player_turn_cap

var stable_od_boss_turn_core_damage_comeback: int:
	get:
		return _stable_od_boss_turn_core_damage_comeback

var used_fallback: bool:
	get:
		return _used_fallback

var validation_errors: Array[String]:
	get:
		return _validation_errors.duplicate()


func _init(values: Dictionary, fallback_used: bool = false, errors: Array[String] = []) -> void:
	_od_max = int(values.get("od_max", 10))

	var zones: Array = values.get("zones", [])
	var calm: Dictionary = zones[0] if zones.size() > 0 else {"min": 0, "max": 3}
	var heated: Dictionary = zones[1] if zones.size() > 1 else {"min": 4, "max": 7}
	var overdrive: Dictionary = zones[2] if zones.size() > 2 else {"min": 8, "max": 10}

	_calm_min = int(calm.get("min", 0))
	_calm_max = int(calm.get("max", 3))
	_heated_min = int(heated.get("min", 4))
	_heated_max = int(heated.get("max", 7))
	_overdrive_min = int(overdrive.get("min", 8))
	_overdrive_max = int(overdrive.get("max", 10))

	var depth: Dictionary = values.get("depth", {})
	_depth_max = int(depth.get("max", 6))
	_depth_end_turn_recover = int(depth.get("end_turn_recover", 2))
	_depth_backlash_threshold = int(depth.get("backlash_threshold", 6))
	_depth_control_reduce = int(depth.get("control_reduce", 1))

	var stable_combat_od: Dictionary = values.get("stable_combat_od", {})
	_stable_od_first_unit_damage = int(stable_combat_od.get("first_unit_damage", 1))
	_stable_od_first_enemy_destroyed = int(stable_combat_od.get("first_enemy_destroyed", 1))
	_stable_od_player_turn_cap = int(stable_combat_od.get("player_turn_cap", 2))
	_stable_od_boss_turn_core_damage_comeback = int(stable_combat_od.get("boss_turn_core_damage_comeback", 1))

	_used_fallback = fallback_used
	_validation_errors = errors.duplicate()


static func default_snapshot(errors: Array[String] = []):
	return new({
		"od_max": 10,
		"zones": [
			{"id": "Calm", "min": 0, "max": 3},
			{"id": "Heated", "min": 4, "max": 7},
			{"id": "Overdrive", "min": 8, "max": 10},
		],
		"depth": {
			"max": 6,
			"end_turn_recover": 2,
			"backlash_threshold": 6,
			"control_reduce": 1,
		},
		"stable_combat_od": {
			"first_unit_damage": 1,
			"first_enemy_destroyed": 1,
			"player_turn_cap": 2,
			"boss_turn_core_damage_comeback": 1,
		},
	}, not errors.is_empty(), errors)


func get_od_zone_id(value: int) -> String:
	var clamped := clamp_od(value)
	if clamped >= _calm_min and clamped <= _calm_max:
		return "Calm"
	if clamped >= _heated_min and clamped <= _heated_max:
		return "Heated"
	if clamped >= _overdrive_min and clamped <= _overdrive_max:
		return "Overdrive"
	return "Unknown"


func clamp_od(value: int) -> int:
	return clampi(value, 0, _od_max)


func clamp_depth(value: int) -> int:
	return clampi(value, 0, _depth_max)


func is_backlash_depth(value: int) -> bool:
	return value >= _depth_backlash_threshold
