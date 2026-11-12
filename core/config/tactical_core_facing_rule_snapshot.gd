extends RefCounted
class_name TacticalCoreFacingRuleSnapshot

## Phase 27C: Core Breach, Facing, and Rear-Defense immutable rule snapshot.
##
## Owns: core/threat ranks, default facing, turn cost, engagement flags,
## Guard intercept geometry, and OD breach parameters only.
## Does NOT duplicate: grid dimensions, pattern offsets, action budget,
## OD maximum, Depth maximum.

# ── Core ──
var _player_target_virtual_rank: int = -1
var _boss_target_virtual_rank: int = 5
var _player_breach_rank: int = 0
var _boss_breach_rank: int = 4
var _player_threat_rank: int = 1
var _boss_threat_rank: int = 3
var _core_spans_all_columns: bool = true
var _legacy_lane_fallback_enabled: bool = false
var _guard_intercept_column_radius: int = 1

# ── Facing ──
var _player_default_rank_delta: int = -1
var _boss_default_rank_delta: int = 1
var _turn_action_cost: int = 1
var _turn_blocked_by_summoning_sickness: bool = true
var _redeploy_resets_to_side_default: bool = true

# ── Engagement ──
var _engagement_enabled: bool = true
var _engagement_locks_self_move: bool = false
var _forced_effect_ignores_lock: bool = true

# ── Overdrive breach ──
var _overdrive_breach_enabled: bool = true
var _overdrive_breach_charge_cost: int = 3
var _overdrive_breach_depth_gain: int = 1
var _overdrive_breach_once_per_turn: bool = true

# ── Metadata ──
var _used_fallback: bool = false
var _validation_errors: Array[String] = []


func _init(table: Dictionary = {}, used_fallback: bool = false, errors: Array[String] = []) -> void:
	_used_fallback = used_fallback
	_validation_errors = errors.duplicate()
	if table.is_empty():
		return

	var core: Dictionary = table.get("core", {})
	if not core.is_empty():
		_player_target_virtual_rank = int(core.get("player_target_virtual_rank", _player_target_virtual_rank))
		_boss_target_virtual_rank = int(core.get("boss_target_virtual_rank", _boss_target_virtual_rank))
		_player_breach_rank = int(core.get("player_breach_rank", _player_breach_rank))
		_boss_breach_rank = int(core.get("boss_breach_rank", _boss_breach_rank))
		_player_threat_rank = int(core.get("player_threat_rank", _player_threat_rank))
		_boss_threat_rank = int(core.get("boss_threat_rank", _boss_threat_rank))
		_core_spans_all_columns = bool(core.get("core_spans_all_columns", _core_spans_all_columns))
		_legacy_lane_fallback_enabled = bool(core.get("legacy_lane_fallback_enabled", _legacy_lane_fallback_enabled))
		_guard_intercept_column_radius = int(core.get("guard_intercept_column_radius", _guard_intercept_column_radius))

	var facing: Dictionary = table.get("facing", {})
	if not facing.is_empty():
		_player_default_rank_delta = int(facing.get("player_default_rank_delta", _player_default_rank_delta))
		_boss_default_rank_delta = int(facing.get("boss_default_rank_delta", _boss_default_rank_delta))
		_turn_action_cost = int(facing.get("turn_action_cost", _turn_action_cost))
		_turn_blocked_by_summoning_sickness = bool(facing.get("turn_blocked_by_summoning_sickness", _turn_blocked_by_summoning_sickness))
		_redeploy_resets_to_side_default = bool(facing.get("redeploy_resets_to_side_default", _redeploy_resets_to_side_default))

	var engagement: Dictionary = table.get("engagement", {})
	if not engagement.is_empty():
		_engagement_enabled = bool(engagement.get("enabled", _engagement_enabled))
		_engagement_locks_self_move = bool(engagement.get("locks_self_move", _engagement_locks_self_move))
		_forced_effect_ignores_lock = bool(engagement.get("forced_effect_ignores_lock", _forced_effect_ignores_lock))

	var od_breach: Dictionary = table.get("overdrive_breach", {})
	if not od_breach.is_empty():
		_overdrive_breach_enabled = bool(od_breach.get("enabled", _overdrive_breach_enabled))
		_overdrive_breach_charge_cost = int(od_breach.get("charge_cost", _overdrive_breach_charge_cost))
		_overdrive_breach_depth_gain = int(od_breach.get("depth_gain", _overdrive_breach_depth_gain))
		_overdrive_breach_once_per_turn = bool(od_breach.get("once_per_turn", _overdrive_breach_once_per_turn))


# ══════════════════════════════════════════════════════════════
# Core API
# ══════════════════════════════════════════════════════════════

func get_default_facing(owner_side: StringName) -> int:
	if owner_side == &"boss":
		return _boss_default_rank_delta
	return _player_default_rank_delta


func get_core_virtual_rank(target_side: StringName) -> int:
	## Returns the virtual rank of the TARGET core.
	## target_side="boss" → player wants boss core (rank -1).
	## target_side="player" → boss wants player core (rank 5).
	if target_side == &"boss":
		return _player_target_virtual_rank
	return _boss_target_virtual_rank


func get_breach_rank(attacker_side: StringName) -> int:
	if attacker_side == &"boss":
		return _boss_breach_rank
	return _player_breach_rank


func get_threat_rank(attacker_side: StringName) -> int:
	if attacker_side == &"boss":
		return _boss_threat_rank
	return _player_threat_rank


func is_legacy_lane_fallback_enabled() -> bool:
	return _legacy_lane_fallback_enabled


func core_spans_all_columns() -> bool:
	return _core_spans_all_columns


func get_guard_intercept_column_radius() -> int:
	return _guard_intercept_column_radius


# ══════════════════════════════════════════════════════════════
# Facing API
# ══════════════════════════════════════════════════════════════

func get_turn_action_cost() -> int:
	return _turn_action_cost


func is_turn_blocked_by_summoning_sickness() -> bool:
	return _turn_blocked_by_summoning_sickness


func redeploy_resets_to_side_default() -> bool:
	return _redeploy_resets_to_side_default


# ══════════════════════════════════════════════════════════════
# Engagement API
# ══════════════════════════════════════════════════════════════

func is_engagement_enabled() -> bool:
	return _engagement_enabled


func engagement_locks_self_move() -> bool:
	return _engagement_locks_self_move


func forced_effect_ignores_engagement() -> bool:
	return _forced_effect_ignores_lock


# ══════════════════════════════════════════════════════════════
# Overdrive breach API
# ══════════════════════════════════════════════════════════════

func is_overdrive_breach_enabled() -> bool:
	return _overdrive_breach_enabled


func get_overdrive_breach_charge_cost() -> int:
	return _overdrive_breach_charge_cost


func get_overdrive_breach_depth_gain() -> int:
	return _overdrive_breach_depth_gain


func overdrive_breach_once_per_turn() -> bool:
	return _overdrive_breach_once_per_turn


# ══════════════════════════════════════════════════════════════
# Metadata
# ══════════════════════════════════════════════════════════════

func used_fallback() -> bool:
	return _used_fallback


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func to_snapshot() -> Dictionary:
	return {
		"core": {
			"player_target_virtual_rank": _player_target_virtual_rank,
			"boss_target_virtual_rank": _boss_target_virtual_rank,
			"player_breach_rank": _player_breach_rank,
			"boss_breach_rank": _boss_breach_rank,
			"player_threat_rank": _player_threat_rank,
			"boss_threat_rank": _boss_threat_rank,
			"core_spans_all_columns": _core_spans_all_columns,
			"legacy_lane_fallback_enabled": _legacy_lane_fallback_enabled,
			"guard_intercept_column_radius": _guard_intercept_column_radius,
		},
		"facing": {
			"player_default_rank_delta": _player_default_rank_delta,
			"boss_default_rank_delta": _boss_default_rank_delta,
			"turn_action_cost": _turn_action_cost,
			"turn_blocked_by_summoning_sickness": _turn_blocked_by_summoning_sickness,
			"redeploy_resets_to_side_default": _redeploy_resets_to_side_default,
		},
		"engagement": {
			"enabled": _engagement_enabled,
			"locks_self_move": _engagement_locks_self_move,
			"forced_effect_ignores_lock": _forced_effect_ignores_lock,
		},
		"overdrive_breach": {
			"enabled": _overdrive_breach_enabled,
			"charge_cost": _overdrive_breach_charge_cost,
			"depth_gain": _overdrive_breach_depth_gain,
			"once_per_turn": _overdrive_breach_once_per_turn,
		},
		"used_fallback": _used_fallback,
	}
