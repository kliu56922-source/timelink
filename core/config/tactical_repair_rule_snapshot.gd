extends RefCounted
class_name TacticalRepairRuleSnapshot
## Invalid configuration grants no capability. No battle or payment state.
var _enabled := false
var _errors: Array[String] = []

static func from_table(table: Dictionary) -> RefCounted:
	return TacticalRepairRuleSnapshot.new(table)

func _init(table: Dictionary = {}) -> void:
	if not _integer_equals(table.get("schema_version"), 1):
		_errors.append("schema_version must be 1")
	if not table.get("enabled") is bool:
		_errors.append("enabled must be bool")
	if table.get("card_ids") != ["P22"]:
		_errors.append("card_ids must be [P22]")
	if table.get("module_kinds") != ["wall", "gatehouse"]:
		_errors.append("module_kinds must be [wall, gatehouse]")
	for key in table:
		if not key is String or key not in ["schema_version", "enabled", "card_ids", "module_kinds"]:
			_errors.append("unknown field: " + str(key))
	if _errors.is_empty():
		_enabled = table.enabled

func is_enabled() -> bool:
	return _enabled

func is_card_supported(card_id: StringName) -> bool:
	return _enabled and card_id == &"P22"

func get_snapshot() -> Dictionary:
	return {"schema_version": 1, "enabled": _enabled, "card_ids": ["P22"],
		"module_kinds": ["wall", "gatehouse"], "validation_errors": _errors.duplicate()}

static func _integer_equals(value: Variant, expected: int) -> bool:
	return (value is int and value == expected) or (value is float and is_finite(value) and value == float(expected))
