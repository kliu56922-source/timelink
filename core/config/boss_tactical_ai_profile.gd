extends RefCounted
class_name BossTacticalAIProfile

const ZONES: Array[String] = ["Calm", "Heated", "Overdrive"]
const WEIGHT_KEYS: Array[String] = [
	"move", "attack", "attack_core", "turn", "skill",
	"lethal", "kill", "protect_core", "advance", "retreat",
	"threat", "cost_penalty",
]

var _schema_version: int = 1
var _max_actions_per_turn: int = 6
var _action_step_delay: float = 0.28
var _minimum_score: int = 0
var _seed_salt: int = 2706
var _weights: Dictionary = {}
var _used_fallback: bool = false
var _validation_errors: Array[String] = []


func _init(table: Dictionary = {}, used_fallback: bool = false, errors: Array[String] = []) -> void:
	_used_fallback = used_fallback
	_validation_errors = errors.duplicate()
	_install_defaults()
	if table.is_empty():
		return
	_schema_version = int(table.get("schema_version", _schema_version))
	_max_actions_per_turn = int(table.get("max_actions_per_turn", _max_actions_per_turn))
	_action_step_delay = clampf(float(table.get("action_step_delay", _action_step_delay)), 0.15, 0.80)
	_minimum_score = int(table.get("minimum_score", _minimum_score))
	_seed_salt = int(table.get("seed_salt", _seed_salt))
	var raw_weights: Dictionary = table.get("weights", {})
	for zone in ZONES:
		var zone_weights: Dictionary = raw_weights.get(zone, {})
		if zone_weights.is_empty():
			continue
		for key in WEIGHT_KEYS:
			if zone_weights.has(key):
				_weights[zone][key] = int(zone_weights[key])


func _install_defaults() -> void:
	var defaults := {
		"move": 20, "attack": 30, "attack_core": 30, "turn": 15, "skill": 30,
		"lethal": 150, "kill": 70, "protect_core": 25, "advance": 20,
		"retreat": 10, "threat": 15, "cost_penalty": 3,
	}
	for zone in ZONES:
		_weights[zone] = defaults.duplicate(true)


func is_valid() -> bool:
	return not _used_fallback and _validation_errors.is_empty() and _schema_version >= 1


func get_max_actions_per_turn() -> int:
	return _max_actions_per_turn


func get_action_step_delay() -> float:
	return _action_step_delay


func get_minimum_score() -> int:
	return _minimum_score


func get_seed_salt() -> int:
	return _seed_salt


func get_zone_weights(zone: String) -> Dictionary:
	return (_weights.get(zone, _weights["Calm"]) as Dictionary).duplicate(true)


func get_weight(zone: String, key: String) -> int:
	var zone_weights: Dictionary = _weights.get(zone, _weights["Calm"])
	return int(zone_weights.get(key, 0))


func used_fallback() -> bool:
	return _used_fallback


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func to_snapshot() -> Dictionary:
	return {
		"schema_version": _schema_version,
		"max_actions_per_turn": _max_actions_per_turn,
			"action_step_delay": _action_step_delay,
		"minimum_score": _minimum_score,
		"seed_salt": _seed_salt,
		"weights": _weights.duplicate(true),
	}
