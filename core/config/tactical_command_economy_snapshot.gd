extends RefCounted
class_name TacticalCommandEconomySnapshot
## Phase 27D: Shared Command Economy immutable rule snapshot.
##
## Owns: player/Boss base command points, ordinary action costs, Depth thresholds,
## skill surcharges, and refund rules. Does NOT duplicate grid, patterns, facing,
## OD maximum, or Depth maximum.

# ── Pool ──
var _player_base_by_layer: Dictionary = {"1": 3, "2": 4, "3": 5, "4": 6, "5": 7}
var _boss_base_by_zone: Dictionary = {"Calm": 3, "Heated": 4, "Overdrive": 5}
var _total_cap: int = 9

# ── Costs ──
var _cost_move: int = 1
var _cost_special_move: int = 2
var _cost_attack: int = 2
var _cost_turn: int = 1
var _cost_defend: int = 1
var _cost_boss_core_attack: int = 3
var _active_skill_min: int = 2
var _active_skill_default: int = 2
var _active_skill_max: int = 4
var _od_finisher_min: int = 4
var _od_finisher_default: int = 4
var _od_finisher_max: int = 6
var _minimum_paid_cost: int = 1

# ── Depth ──
var _gross_spend_thresholds: Array[int] = [3, 6, 8]
var _depth_per_threshold: int = 1
var _warning_skill_surcharge: int = 1
var _backlash_skill_surcharge: int = 1
var _block_instant_refund_during_backlash: bool = true

# ── Refunds ──
var _refund_default_per_trigger_cap: int = 1
var _refund_total_per_turn_cap: int = 2

# ── Turn lifecycle ──
var _clear_unused_points: bool = true
var _normal_gain_applies_next_turn: bool = true

# ── Metadata ──
var _used_fallback: bool = false
var _validation_errors: Array[String] = []


func _init(table: Dictionary = {}, used_fallback: bool = false, errors: Array[String] = []) -> void:
	_used_fallback = used_fallback
	_validation_errors = errors.duplicate()
	if table.is_empty():
		return

	var pool: Dictionary = table.get("pool", {})
	if not pool.is_empty():
		var player_base: Dictionary = pool.get("player_base_by_od_layer", {})
		if not player_base.is_empty():
			for key in player_base.keys():
				_player_base_by_layer[str(key)] = int(player_base[key])
		var boss_base: Dictionary = pool.get("boss_base_by_zone", {})
		if not boss_base.is_empty():
			for key in boss_base.keys():
				_boss_base_by_zone[str(key)] = int(boss_base[key])
		_total_cap = int(pool.get("total_cap", _total_cap))

	var costs: Dictionary = table.get("costs", {})
	if not costs.is_empty():
		_cost_move = int(costs.get("move", _cost_move))
		_cost_special_move = int(costs.get("special_move", _cost_special_move))
		_cost_attack = int(costs.get("attack", _cost_attack))
		_cost_turn = int(costs.get("turn", _cost_turn))
		_cost_defend = int(costs.get("defend", _cost_defend))
		_cost_boss_core_attack = int(costs.get("boss_core_attack", _cost_boss_core_attack))
		var active: Dictionary = costs.get("active_skill", {})
		if not active.is_empty():
			_active_skill_min = int(active.get("min", _active_skill_min))
			_active_skill_default = int(active.get("default", _active_skill_default))
			_active_skill_max = int(active.get("max", _active_skill_max))
		var finisher: Dictionary = costs.get("od_finisher", {})
		if not finisher.is_empty():
			_od_finisher_min = int(finisher.get("min", _od_finisher_min))
			_od_finisher_default = int(finisher.get("default", _od_finisher_default))
			_od_finisher_max = int(finisher.get("max", _od_finisher_max))
		_minimum_paid_cost = int(costs.get("minimum_paid_cost", _minimum_paid_cost))

	var depth: Dictionary = table.get("depth", {})
	if not depth.is_empty():
		var thresholds_raw: Array = depth.get("gross_spend_thresholds", _gross_spend_thresholds)
		_gross_spend_thresholds.clear()
		for raw in thresholds_raw:
			_gross_spend_thresholds.append(int(raw))
		_depth_per_threshold = int(depth.get("depth_per_threshold", _depth_per_threshold))
		_warning_skill_surcharge = int(depth.get("warning_skill_surcharge", _warning_skill_surcharge))
		_backlash_skill_surcharge = int(depth.get("backlash_skill_surcharge", _backlash_skill_surcharge))
		_block_instant_refund_during_backlash = bool(depth.get("block_instant_refund_during_backlash", _block_instant_refund_during_backlash))

	var refunds: Dictionary = table.get("refunds", {})
	if not refunds.is_empty():
		_refund_default_per_trigger_cap = int(refunds.get("default_per_trigger_cap", _refund_default_per_trigger_cap))
		_refund_total_per_turn_cap = int(refunds.get("total_per_turn_cap", _refund_total_per_turn_cap))

	var turn: Dictionary = table.get("turn", {})
	if not turn.is_empty():
		_clear_unused_points = bool(turn.get("clear_unused_points", _clear_unused_points))
		_normal_gain_applies_next_turn = bool(turn.get("normal_gain_applies_next_turn", _normal_gain_applies_next_turn))


# ═══════════════════════════════════════════════
# Pool API
# ═══════════════════════════════════════════════

func get_player_base_points(layer: int) -> int:
	return int(_player_base_by_layer.get(str(layer), 3))


func get_boss_base_points(zone: String) -> int:
	return int(_boss_base_by_zone.get(zone, 3))


func get_total_cap() -> int:
	return _total_cap


# ═══════════════════════════════════════════════
# Cost API
# ═══════════════════════════════════════════════

func get_base_command_cost(command_type: String) -> int:
	match command_type:
		"move": return _cost_move
		"special_move": return _cost_special_move
		"attack": return _cost_attack
		"turn": return _cost_turn
		"defend": return _cost_defend
		"attack_core": return _cost_boss_core_attack
		"boss_core_attack": return _cost_boss_core_attack
		_: return 0


func get_active_skill_cost(raw_cost: int = -1) -> int:
	if raw_cost < 0:
		return _active_skill_default
	return clampi(raw_cost, _active_skill_min, _active_skill_max)


func get_od_finisher_cost(raw_cost: int = -1) -> int:
	if raw_cost < 0:
		return _od_finisher_default
	return clampi(raw_cost, _od_finisher_min, _od_finisher_max)


func get_minimum_paid_cost() -> int:
	return _minimum_paid_cost


# ═══════════════════════════════════════════════
# Depth API
# ═══════════════════════════════════════════════

func get_depth_thresholds() -> Array[int]:
	return _gross_spend_thresholds.duplicate()


func get_depth_per_threshold() -> int:
	return _depth_per_threshold


func get_skill_surcharge(depth_zone: String) -> int:
	match depth_zone:
		"Warning": return _warning_skill_surcharge
		"Backlash": return _backlash_skill_surcharge
		_: return 0


func blocks_instant_refund(depth_zone: String) -> bool:
	if depth_zone == "Backlash":
		return _block_instant_refund_during_backlash
	return false


# ═══════════════════════════════════════════════
# Refund API
# ═══════════════════════════════════════════════

func get_refund_default_per_trigger_cap() -> int:
	return _refund_default_per_trigger_cap


func get_refund_total_per_turn_cap() -> int:
	return _refund_total_per_turn_cap


# ═══════════════════════════════════════════════
# Turn lifecycle API
# ═══════════════════════════════════════════════

func clear_unused_points() -> bool:
	return _clear_unused_points


func normal_gain_applies_next_turn() -> bool:
	return _normal_gain_applies_next_turn


# ═══════════════════════════════════════════════
# Metadata
# ═══════════════════════════════════════════════

func used_fallback() -> bool:
	return _used_fallback


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func to_snapshot() -> Dictionary:
	return {
		"pool": {
			"player_base_by_od_layer": _player_base_by_layer.duplicate(),
			"boss_base_by_zone": _boss_base_by_zone.duplicate(),
			"total_cap": _total_cap,
		},
		"costs": {
			"move": _cost_move,
			"special_move": _cost_special_move,
			"attack": _cost_attack,
			"turn": _cost_turn,
			"defend": _cost_defend,
			"boss_core_attack": _cost_boss_core_attack,
			"active_skill": {"min": _active_skill_min, "default": _active_skill_default, "max": _active_skill_max},
			"od_finisher": {"min": _od_finisher_min, "default": _od_finisher_default, "max": _od_finisher_max},
			"minimum_paid_cost": _minimum_paid_cost,
		},
		"depth": {
			"gross_spend_thresholds": _gross_spend_thresholds.duplicate(),
			"depth_per_threshold": _depth_per_threshold,
			"warning_skill_surcharge": _warning_skill_surcharge,
			"backlash_skill_surcharge": _backlash_skill_surcharge,
			"block_instant_refund_during_backlash": _block_instant_refund_during_backlash,
		},
		"refunds": {
			"default_per_trigger_cap": _refund_default_per_trigger_cap,
			"total_per_turn_cap": _refund_total_per_turn_cap,
		},
		"turn": {
			"clear_unused_points": _clear_unused_points,
			"normal_gain_applies_next_turn": _normal_gain_applies_next_turn,
		},
		"used_fallback": _used_fallback,
	}
