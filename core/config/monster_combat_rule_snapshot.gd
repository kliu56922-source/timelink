extends RefCounted
class_name MonsterCombatRuleSnapshot

## Phase 25D + Phase 26E: 不可变怪兽战斗规则快照
## 由 GameConfig 在 battle start 一次性创建，注入 BattleSystem。
## 拥有规范化后的规则值，暴露 pure 移动、Guard 和 direct-target 判断方法。

# ── Constants ──

const DEFAULT_MAX_ATTACKS: int = 1
const DEFAULT_BLOCKER: String = "guard_only"
const DEFAULT_RESOLUTION: String = "simultaneous_hp"
const DEFAULT_GUARD_SCOPE: String = "same_and_adjacent"

# Phase 26E: movement pattern constants
const PATTERN_STEP: StringName = &"step"
const PATTERN_SLIDE: StringName = &"slide"
const PATTERN_LEAP: StringName = &"leap"
const PATTERN_ANCHOR: StringName = &"anchor"

# ── Combat fields (Phase 25D) ──

var max_attacks_per_turn: int
var summoning_sickness_enabled: bool
var direct_attack_enabled: bool
var direct_attack_blocker: String
var guard_forces_targeting: bool
var resolution_mode: String
var used_fallback: bool
var validation_errors: Array[String]

# ── Phase 26E: Movement fields ──

var guard_scope: StringName = DEFAULT_GUARD_SCOPE
var movement_enabled: bool = true
var lane_count: int = 5
var actions_per_turn: int = 1
var self_move_action_cost: int = 1
var summoning_sickness_blocks_self_move: bool = true
var forced_move_preserves_action: bool = true
var default_pattern: StringName = PATTERN_STEP
var allowed_patterns: Array[StringName] = [PATTERN_STEP, PATTERN_SLIDE, PATTERN_LEAP, PATTERN_ANCHOR]
var spawn_lane_order: Array[int] = [2, 1, 3, 0, 4]
var mobility_by_card_id: Dictionary = {}
var boss_movement_enabled: bool = true
var boss_move_or_attack: bool = true
var boss_tie_break: StringName = &"nearest_center_then_lower_lane"


func _init(values: Dictionary = {}, fallback_used: bool = false, errors: Array[String] = []) -> void:
	# ── Phase 25D: combat fields ──
	max_attacks_per_turn = int(values.get("max_attacks_per_turn", DEFAULT_MAX_ATTACKS))
	summoning_sickness_enabled = bool(values.get("summoning_sickness_enabled", true))
	var direct_attack: Dictionary = values.get("direct_attack", {})
	direct_attack_enabled = bool(direct_attack.get("enabled", true))
	direct_attack_blocker = str(direct_attack.get("blocker", DEFAULT_BLOCKER))
	var guard: Dictionary = values.get("guard", {})
	guard_forces_targeting = bool(guard.get("forces_targeting", true))
	guard_scope = StringName(str(guard.get("scope", DEFAULT_GUARD_SCOPE)))
	resolution_mode = str(values.get("resolution_mode", DEFAULT_RESOLUTION))
	used_fallback = fallback_used
	validation_errors = errors.duplicate()

	# ── Phase 26E: movement fields ──
	var movement: Dictionary = values.get("movement", {})
	if not movement.is_empty():
		movement_enabled = bool(movement.get("enabled", true))
		lane_count = int(movement.get("lane_count", 5))
		actions_per_turn = int(movement.get("actions_per_turn", 1))
		self_move_action_cost = int(movement.get("self_move_action_cost", 1))
		summoning_sickness_blocks_self_move = bool(movement.get("summoning_sickness_blocks_self_move", true))
		forced_move_preserves_action = bool(movement.get("forced_move_preserves_action", true))
		default_pattern = StringName(str(movement.get("default_pattern", PATTERN_STEP)))

		# allowed_patterns — normalize to Array[StringName]
		allowed_patterns.clear()
		for raw in movement.get("allowed_patterns", [PATTERN_STEP]):
			allowed_patterns.append(StringName(str(raw)))

		# spawn_lane_order — normalize to Array[int]
		spawn_lane_order.clear()
		for raw in movement.get("spawn_lane_order", [2, 1, 3, 0, 4]):
			spawn_lane_order.append(int(raw))

		# mobility_by_card_id — duplicate to prevent JSON mutation
		var raw_mob: Dictionary = movement.get("mobility_by_card_id", {})
		mobility_by_card_id.clear()
		for key in raw_mob:
			mobility_by_card_id[StringName(str(key))] = StringName(str(raw_mob[key]))

	# ── Phase 26E: boss_movement fields ──
	var boss_move: Dictionary = values.get("boss_movement", {})
	if not boss_move.is_empty():
		boss_movement_enabled = bool(boss_move.get("enabled", true))
		boss_move_or_attack = bool(boss_move.get("move_or_attack", true))
		boss_tie_break = StringName(str(boss_move.get("tie_break", "nearest_center_then_lower_lane")))


static func default_snapshot(errors: Array[String] = []) -> MonsterCombatRuleSnapshot:
	var values: Dictionary = {
		"max_attacks_per_turn": DEFAULT_MAX_ATTACKS,
		"summoning_sickness_enabled": true,
		"direct_attack": {"enabled": true, "blocker": DEFAULT_BLOCKER},
		"guard": {"forces_targeting": true, "scope": DEFAULT_GUARD_SCOPE},
		"resolution_mode": DEFAULT_RESOLUTION,
		"movement": {
			"enabled": true, "lane_count": 5, "actions_per_turn": 1,
			"self_move_action_cost": 1, "summoning_sickness_blocks_self_move": true,
			"forced_move_preserves_action": true, "default_pattern": "step",
			"allowed_patterns": ["step", "slide", "leap", "anchor"],
			"spawn_lane_order": [2, 1, 3, 0, 4],
			"mobility_by_card_id": {}
		},
		"boss_movement": {"enabled": true, "move_or_attack": true, "tie_break": "nearest_center_then_lower_lane"},
	}
	var snap := MonsterCombatRuleSnapshot.new(values, true, errors.duplicate())
	return snap


# ── Phase 26E: Pure movement query methods (no scene nodes, no mutable state) ──

func get_lane_count() -> int:
	return lane_count

func get_actions_per_turn() -> int:
	return actions_per_turn

func get_spawn_lane_order() -> Array[int]:
	return spawn_lane_order.duplicate()

func get_movement_pattern(card_id: StringName) -> StringName:
	var result: Variant = mobility_by_card_id.get(card_id, null)
	if result != null:
		return StringName(str(result))
	return default_pattern

func _lane_empty(lane: int, occupied: Dictionary) -> bool:
	return lane >= 0 and lane < lane_count and not occupied.has(lane)

func get_legal_move_lanes(pattern: StringName, from_lane: int, occupied: Dictionary) -> Array[int]:
	var legal: Array[int] = []
	if not movement_enabled or from_lane < 0 or from_lane >= lane_count:
		return legal
	match pattern:
		PATTERN_STEP:
			for lane in [from_lane - 1, from_lane + 1]:
				if _lane_empty(lane, occupied):
					legal.append(lane)
		PATTERN_LEAP:
			for lane in [from_lane - 2, from_lane + 2]:
				if _lane_empty(lane, occupied):
					legal.append(lane)
		PATTERN_SLIDE:
			var dir: int = -1
			while dir <= 1:
				if dir == 0:
					dir += 1
					continue
				var lane: int = from_lane + dir
				while lane >= 0 and lane < lane_count:
					if occupied.has(lane):
						break
					legal.append(lane)
					lane += dir
				dir += 1
		PATTERN_ANCHOR:
			pass
	legal.sort()
	return legal

func is_target_in_attack_reach(attacker_lane: int, target_lane: int) -> bool:
	return attacker_lane >= 0 and attacker_lane == target_lane

func is_guard_in_scope(attacker_lane: int, guard_lane: int) -> bool:
	if guard_scope == &"same_and_adjacent":
		return absi(attacker_lane - guard_lane) <= 1
	return attacker_lane == guard_lane


# ── Phase 25D: Pure guard / target helpers (preserved for backward compat) ──

func is_guard(card) -> bool:
	return card != null and card.is_guard_card


func _has_guard(enemy_field: Array) -> bool:
	for card in enemy_field:
		if card is CardData and is_guard(card):
			return true
	return false


func is_legal_unit_target(target, enemy_field: Array) -> bool:
	if target == null or not target in enemy_field:
		return false
	if guard_forces_targeting and _has_guard(enemy_field):
		return is_guard(target)
	return true


func get_direct_attack_block_reason(enemy_field: Array) -> String:
	if not direct_attack_enabled:
		return "当前规则禁止直接攻击 Boss"
	match direct_attack_blocker:
		"guard_only":
			if _has_guard(enemy_field):
				return "Boss 前场仍有守卫"
		"any_enemy":
			if not enemy_field.is_empty():
				return "Boss 前场仍有怪兽"
		"same_lane":
			return ""  # lane-aware check is done by BattleSystem
	return ""
