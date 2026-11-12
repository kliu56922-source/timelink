extends RefCounted
class_name TacticalSiegeRuleSnapshot
## Pure, defensive values. No board, payment, action or presentation state.
const PROFILE_CONTRACTS := {
	"normal_structure_attack": {"structure_steps": 1, "max_manhattan": 1, "max_height_delta": 1},
	"bishop_breach": {"structure_steps": 2, "requires_enchant": true, "overflow": false},
	"p18_wall_pierce": {"hp_per_integrity": 4, "secondary_policy": "active_garrison_else_core", "max_secondary_targets": 1},
	"boss_b07_breach": {"actor_card_id": "B-07", "max_pending": 1, "target_kind": "structure_module", "requires_full_player_window": true},
}
var _enabled := false
var _profiles: Dictionary = {}
var _errors: Array[String] = []

func _init(table: Dictionary = {}) -> void:
	if not _exact_scalar(table.get("schema_version"), 1):
		_errors.append("[tactical_siege_rules] schema_version must be exactly 1")
	if not table.get("enabled") is bool:
		_errors.append("[tactical_siege_rules] enabled must be bool")
	if not table.get("profiles") is Dictionary:
		_errors.append("[tactical_siege_rules] profiles must be Dictionary")
	_reject_unknown(table, ["schema_version", "enabled", "profiles"], "table")
	if not _errors.is_empty():
		return
	_enabled = table.enabled
	var raw: Dictionary = table.profiles
	for profile_id in PROFILE_CONTRACTS:
		var profile: Variant = raw.get(profile_id)
		if not profile is Dictionary:
			_errors.append("[tactical_siege_rules] %s must be Dictionary" % profile_id)
			continue
		var expected: Dictionary = PROFILE_CONTRACTS[profile_id]
		var error_count := _errors.size()
		_reject_unknown(profile, expected.keys(), profile_id)
		for field in expected:
			if not _exact_scalar(profile.get(field), expected[field]):
				_errors.append("[tactical_siege_rules] %s.%s violates exact contract" % [profile_id, field])
		if error_count == _errors.size():
			# Normalize JSON integral floats only AFTER strict validation.
			_profiles[profile_id] = expected.duplicate(true)
	_reject_unknown(raw, PROFILE_CONTRACTS.keys(), "profiles")
	if not _profiles.has("normal_structure_attack") and _profiles.has("boss_b07_breach"):
		_profiles.erase("boss_b07_breach")
		_errors.append("[tactical_siege_rules] boss_b07_breach requires valid normal_structure_attack")

func is_enabled() -> bool:
	return _enabled

func get_profile(profile_id: StringName) -> Dictionary:
	# A disabled snapshot never hands out an active capability.
	if not _enabled:
		return {}
	return _profiles.get(String(profile_id), {}).duplicate(true)

func get_snapshot() -> Dictionary:
	return {"schema_version": 1, "enabled": _enabled, "profiles": _profiles.duplicate(true),
		"used_fallback": not _errors.is_empty(), "validation_errors": _errors.duplicate()}

func _reject_unknown(value: Dictionary, allowed: Array, path: String) -> void:
	for key in value:
		if not key is String or not allowed.has(key):
			_errors.append("[tactical_siege_rules] unknown %s field: %s" % [path, str(key)])

static func _exact_scalar(value: Variant, expected: Variant) -> bool:
	if expected is int:
		if value is int:
			return value == expected
		return value is float and is_finite(value) and value == float(expected)
	return typeof(value) == typeof(expected) and value == expected
