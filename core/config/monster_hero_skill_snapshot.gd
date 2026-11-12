extends RefCounted
class_name MonsterHeroSkillSnapshot
## Phase 27E: 怪兽英雄技能只读快照
## 由 GameConfig 在 battle start 一次性创建。
## 纯查询方法：card_id → 被动/主动技能定义。

const ALLOWED_RESOLVERS: Array[StringName] = [
	&"resolve_ignition_leap",
	&"resolve_stream_cannon",
	&"resolve_bulwark_advance",
]
const ALLOWED_TRIGGERS: Array[StringName] = [
	&"normal_move_completed",
	&"player_od_gained",
	&"monster_combat_damage_received",
]
const ALLOWED_TARGET_MODES: Array[StringName] = [
	&"cell",
	&"enemy_unit_or_boss_core",
	&"cell_or_self",
]

var _skills_by_card: Dictionary = {}
var used_fallback := false
var validation_errors: Array[String] = []

func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	used_fallback = fallback_used
	validation_errors = errors.duplicate()
	if values.is_empty():
		return
	var raw_skills: Array = values.get("skills", [])
	for entry in raw_skills:
		if not entry is Dictionary:
			continue
		var card_id: String = str(entry.get("card_id", ""))
		if card_id.is_empty():
			continue
		var parsed: Dictionary = _parse_skill_entry(entry)
		if not parsed.is_empty():
			_skills_by_card[card_id] = parsed

func _parse_skill_entry(entry: Dictionary) -> Dictionary:
	var passive_raw: Dictionary = entry.get("passive", {})
	var active_raw: Dictionary = entry.get("active", {})
	return {
		"cn_name": str(entry.get("cn_name", "")),
		"passive": {
			"id": StringName(str(passive_raw.get("id", ""))),
			"name": str(passive_raw.get("name", "")),
			"max_stacks": int(passive_raw.get("max_stacks", 0)),
			"trigger": StringName(str(passive_raw.get("trigger", ""))),
		},
		"active": {
			"id": StringName(str(active_raw.get("id", ""))),
			"name": str(active_raw.get("name", "")),
			"command_type": StringName(str(active_raw.get("command_type", "active_skill"))),
			"base_cost": int(active_raw.get("base_cost", 0)),
			"target_mode": StringName(str(active_raw.get("target_mode", ""))),
			"resolver_id": StringName(str(active_raw.get("resolver_id", ""))),
		},
	}

static func default_snapshot(errors: Array[String] = []) -> MonsterHeroSkillSnapshot:
	var inst := new()
	inst.used_fallback = true
	inst.validation_errors = errors.duplicate()
	return inst

## 查询 API
func has_skill(card_id: String) -> bool:
	return _skills_by_card.has(card_id)

func get_passive(card_id: String) -> Dictionary:
	var entry: Dictionary = _skills_by_card.get(card_id, {})
	return entry.get("passive", {})

func get_active(card_id: String) -> Dictionary:
	var entry: Dictionary = _skills_by_card.get(card_id, {})
	return entry.get("active", {})

func get_card_ids() -> Array:
	return _skills_by_card.keys()

func get_skill_by_card_id(card_id: String) -> Dictionary:
	return _skills_by_card.get(card_id, {})
