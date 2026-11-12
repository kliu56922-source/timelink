extends RefCounted
class_name ODReleaseRuleSnapshot
## Immutable Phase 27J OD-release tuning snapshot.

var _values: Dictionary = {}
var _used_fallback := false
var _validation_errors: Array[String] = []

func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	_values = values.duplicate(true)
	_used_fallback = fallback_used
	_validation_errors = errors.duplicate()

static func default_snapshot(errors: Array[String] = []):
	return new({
		"schema_version": 1,
		"readiness_threshold": 8,
		"release_heat_cost": 5,
		"converted_heat": 5,
		"piece_releases": {},
		"final_convergence": {},
	}, true, errors)

func is_fallback() -> bool:
	return _used_fallback

func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func get_readiness_threshold() -> int:
	return int(_values.get("readiness_threshold", 8))

# PHASE62_BEGIN_RITUAL_THRESHOLD
func get_ritual_readiness_threshold() -> int:
	return int(_values.get("ritual_readiness_threshold",get_readiness_threshold()))
# PHASE62_END_RITUAL_THRESHOLD
func get_release_heat_cost() -> int:
	return int(_values.get("release_heat_cost", 5))

func get_converted_heat() -> int:
	return int(_values.get("converted_heat", get_release_heat_cost()))

func get_piece_release(piece_type: StringName) -> Dictionary:
	var releases: Dictionary = _values.get("piece_releases", {})
	return (releases.get(str(piece_type), {}) as Dictionary).duplicate(true)

func get_piece_resolver_id(piece_type: StringName) -> StringName:
	return StringName(str(get_piece_release(piece_type).get("resolver_id", "")))

func get_piece_action_kind(piece_type: StringName) -> StringName:
	return StringName(str(get_piece_release(piece_type).get("action_kind", "")))

func get_piece_command_id(piece_type: StringName) -> StringName:
	return StringName(str(get_piece_release(piece_type).get("command_id", "")))

func get_piece_command_cost(piece_type: StringName) -> int:
	return int(get_piece_release(piece_type).get("command_cost", 0))

func get_knight_disruption_damage() -> int:
	# Optional tuning seam; old/production snapshots retain exactly one damage.
	return int(get_piece_release(&"knight").get("disruption_damage", 1))

func get_piece_chain_event(piece_type: StringName) -> StringName:
	return StringName(str(get_piece_release(piece_type).get("chain_event", "")))

func get_final_convergence_rules() -> Dictionary:
	return (_values.get("final_convergence", {}) as Dictionary).duplicate(true)

func to_snapshot() -> Dictionary:
	return _values.duplicate(true)
