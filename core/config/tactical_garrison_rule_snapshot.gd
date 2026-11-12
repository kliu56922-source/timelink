extends RefCounted
class_name TacticalGarrisonRuleSnapshot

## Elevated Grid Phase D1 — immutable garrison rule snapshot.
## Each override, slot and range profile is parsed independently. Getters return
## defensive copies; the snapshot owns no unit, structure, action or combat state.

const SCHEMA_VERSION := 1
const VALID_SIZE_CLASSES: Array[StringName] = [&"normal", &"large", &"fusion", &"siege_beast"]
const EXPECTED_DENIED_TAGS: Array[StringName] = [&"large", &"fusion", &"siege_beast"]
const EXPECTED_FALLBACK_ORDER: Array[StringName] = [&"rear", &"left", &"right", &"front"]
const P07_RANGE_PROFILE: StringName = &"p07_channeler_high_ground"
const P08_SLOT_KEY: StringName = &"p08_fortification:garrison_0"

var schema_version := SCHEMA_VERSION
var used_fallback := false
var validation_errors: Array[String] = []

var _enabled := false
var _default_unit_profile: Dictionary = {}
var _denied_tags: Array[StringName] = []
var _unit_overrides: Dictionary = {}
var _structure_slots: Dictionary = {}
var _range_profiles: Dictionary = {}
var _fallback_relative_order: Array[StringName] = []


func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	used_fallback = fallback_used
	validation_errors = errors.duplicate()
	if values.is_empty() or not _is_int_like(values.get("schema_version", null)) or int(values.get("schema_version", 0)) != SCHEMA_VERSION:
		used_fallback = true
		_append_error("table envelope is missing or schema_version is not 1")
		return

	var default_parsed := _parse_unit_profile(&"default", values.get("default_unit_profile", null), true)
	var denied_parsed := _parse_denied_tags(values.get("denied_tags", null))
	if not bool(default_parsed.get("ok", false)) or not bool(denied_parsed.get("ok", false)):
		used_fallback = true
		_append_parse_errors("default_unit_profile", default_parsed.get("errors", []))
		_append_parse_errors("denied_tags", denied_parsed.get("errors", []))
		return

	_default_unit_profile = (default_parsed.get("data", {}) as Dictionary).duplicate(true)
	_denied_tags.assign(denied_parsed.get("data", []))
	_enabled = true
	_parse_unit_overrides(values.get("unit_overrides", null))
	_parse_structure_slots(values.get("structure_slots", null))
	_parse_range_profiles(values.get("range_profiles", null))
	_parse_fallback_order(values.get("fallback_landing_relative_order", null))


static func disabled_snapshot(errors: Array[String] = []) -> RefCounted:
	var snapshot := new()
	snapshot.used_fallback = true
	snapshot.validation_errors = errors.duplicate()
	return snapshot


func _append_error(detail: String) -> void:
	var message := "[CONFIG ERROR] tactical_garrison_rules: %s" % detail
	if not validation_errors.has(message):
		validation_errors.append(message)


func _append_parse_errors(section: String, errors: Array) -> void:
	for error in errors:
		_append_error("%s: %s" % [section, str(error)])


func _parse_unit_overrides(raw: Variant) -> void:
	if not raw is Dictionary:
		_append_error("unit_overrides must be a Dictionary")
		return
	for raw_card_id in (raw as Dictionary):
		var card_id := StringName(str(raw_card_id))
		if card_id == &"":
			_append_error("unit_overrides contains an empty card id")
			continue
		var parsed := _parse_unit_profile(card_id, (raw as Dictionary)[raw_card_id], false)
		if bool(parsed.get("ok", false)):
			_unit_overrides[card_id] = (parsed.get("data", {}) as Dictionary).duplicate(true)
		else:
			_append_parse_errors("unit_overrides.%s" % card_id, parsed.get("errors", []))


func _parse_structure_slots(raw: Variant) -> void:
	if not raw is Dictionary:
		_append_error("structure_slots must be a Dictionary")
		return
	for raw_key in (raw as Dictionary):
		var slot_key := StringName(str(raw_key))
		var parsed := _parse_slot_profile(slot_key, (raw as Dictionary)[raw_key])
		if bool(parsed.get("ok", false)):
			_structure_slots[slot_key] = (parsed.get("data", {}) as Dictionary).duplicate(true)
		else:
			_append_parse_errors("structure_slots.%s" % slot_key, parsed.get("errors", []))


func _parse_range_profiles(raw: Variant) -> void:
	if not raw is Dictionary:
		_append_error("range_profiles must be a Dictionary")
		return
	for raw_profile_id in (raw as Dictionary):
		var profile_id := StringName(str(raw_profile_id))
		var parsed := _parse_range_profile(profile_id, (raw as Dictionary)[raw_profile_id])
		if bool(parsed.get("ok", false)):
			_range_profiles[profile_id] = (parsed.get("data", {}) as Dictionary).duplicate(true)
		else:
			_append_parse_errors("range_profiles.%s" % profile_id, parsed.get("errors", []))


func _parse_fallback_order(raw: Variant) -> void:
	if not raw is Array or (raw as Array).size() != EXPECTED_FALLBACK_ORDER.size():
		_append_error("fallback_landing_relative_order must be rear,left,right,front")
		return
	var parsed: Array[StringName] = []
	for value in raw as Array:
		if not value is String:
			_append_error("fallback_landing_relative_order values must be String")
			return
		parsed.append(StringName(value))
	if parsed != EXPECTED_FALLBACK_ORDER:
		_append_error("fallback_landing_relative_order must be rear,left,right,front")
		return
	_fallback_relative_order = parsed.duplicate()


func _parse_unit_profile(card_id: StringName, raw: Variant, is_default: bool) -> Dictionary:
	var errors: Array[String] = []
	if not raw is Dictionary:
		return {"ok": false, "errors": ["profile must be a Dictionary"]}
	var profile: Dictionary = raw
	var can_garrison: Variant = profile.get("can_garrison", null)
	var size_raw: Variant = profile.get("size_class", null)
	var range_raw: Variant = profile.get("range_profile_id", null)
	if not can_garrison is bool:
		errors.append("can_garrison must be bool")
	if not size_raw is String or String(size_raw).is_empty() or not StringName(size_raw) in VALID_SIZE_CLASSES:
		errors.append("size_class must be normal, large, fusion or siege_beast")
	if not range_raw is String or String(range_raw).is_empty():
		errors.append("range_profile_id must be a non-empty String")
	if errors.is_empty():
		if is_default:
			if not bool(can_garrison) or StringName(size_raw) != &"normal" or StringName(range_raw) != &"none":
				errors.append("default profile must be true, normal, none")
		elif card_id == &"P07":
			if not bool(can_garrison) or StringName(size_raw) != &"normal" or StringName(range_raw) != P07_RANGE_PROFILE:
				errors.append("P07 override must be true, normal, p07_channeler_high_ground")
		elif card_id == &"P15":
			if not bool(can_garrison) or StringName(size_raw) != &"normal" or StringName(range_raw) != &"none":
				errors.append("P15 override must be true, normal, none")
		elif card_id == &"A06":
			if bool(can_garrison) or StringName(size_raw) != &"large" or StringName(range_raw) != &"none":
				errors.append("A06 override must be false, large, none")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {
		"ok": true,
		"data": {
			"can_garrison": bool(can_garrison),
			"size_class": StringName(size_raw),
			"range_profile_id": StringName(range_raw),
		},
	}


func _parse_denied_tags(raw: Variant) -> Dictionary:
	if not raw is Array or (raw as Array).size() != EXPECTED_DENIED_TAGS.size():
		return {"ok": false, "errors": ["must contain large, fusion and siege_beast exactly once"]}
	var parsed: Array[StringName] = []
	for value in raw as Array:
		if not value is String or String(value).is_empty():
			return {"ok": false, "errors": ["values must be non-empty String"]}
		var tag := StringName(value)
		if parsed.has(tag):
			return {"ok": false, "errors": ["contains duplicate tag %s" % tag]}
		parsed.append(tag)
	for required in EXPECTED_DENIED_TAGS:
		if not parsed.has(required):
			return {"ok": false, "errors": ["missing denied tag %s" % required]}
	return {"ok": true, "data": parsed}


func _parse_slot_profile(slot_key: StringName, raw: Variant) -> Dictionary:
	var errors: Array[String] = []
	if slot_key != P08_SLOT_KEY:
		errors.append("slot key must be p08_fortification:garrison_0")
	if not raw is Dictionary:
		errors.append("slot profile must be a Dictionary")
		return {"ok": false, "errors": errors}
	var slot: Dictionary = raw
	var enabled: Variant = slot.get("enabled", null)
	var height: Variant = slot.get("platform_height_offset", null)
	if not enabled is bool or enabled != true:
		errors.append("enabled must be true")
	if not slot.get("slot_role", null) is String or StringName(str(slot.get("slot_role", ""))) != &"rampart":
		errors.append("slot_role must be rampart")
	if not slot.get("socket_name", null) is String or StringName(str(slot.get("socket_name", ""))) != &"Garrison0":
		errors.append("socket_name must be Garrison0")
	if not _is_int_like(height) or int(height) != 1:
		errors.append("platform_height_offset must be 1")
	if not slot.get("support_relative_edge", null) is String or StringName(str(slot.get("support_relative_edge", ""))) != &"front":
		errors.append("support_relative_edge must be front")
	if not slot.get("entry_mode", null) is String or StringName(str(slot.get("entry_mode", ""))) != &"adjacent_height_or_owner_passage":
		errors.append("entry_mode must be adjacent_height_or_owner_passage")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {
		"ok": true,
		"data": {
			"enabled": true,
			"slot_role": &"rampart",
			"socket_name": &"Garrison0",
			"platform_height_offset": 1,
			"support_relative_edge": &"front",
			"entry_mode": &"adjacent_height_or_owner_passage",
		},
	}


func _parse_range_profile(profile_id: StringName, raw: Variant) -> Dictionary:
	var errors: Array[String] = []
	if profile_id != P07_RANGE_PROFILE:
		errors.append("range profile id must be p07_channeler_high_ground")
	if not raw is Dictionary:
		errors.append("range profile must be a Dictionary")
		return {"ok": false, "errors": errors}
	var profile: Dictionary = raw
	if not profile.get("applies_to", null) is String or StringName(str(profile.get("applies_to", ""))) != &"normal_attack":
		errors.append("applies_to must be normal_attack")
	if not profile.get("requires_strict_height_advantage", null) is bool or profile.get("requires_strict_height_advantage") != true:
		errors.append("requires_strict_height_advantage must be true")
	var offsets := _parse_offsets(profile.get("extra_attack_offsets", null))
	if not bool(offsets.get("ok", false)):
		errors.append("extra_attack_offsets must be [-1,-2],[0,-2],[1,-2]")
	var damage: Variant = profile.get("damage_bonus", null)
	if not _is_int_like(damage) or int(damage) != 0:
		errors.append("damage_bonus must be 0")
	if not profile.get("affects_boss_core", null) is bool or profile.get("affects_boss_core") != false:
		errors.append("affects_boss_core must be false")
	if not profile.get("affects_active_skill", null) is bool or profile.get("affects_active_skill") != false:
		errors.append("affects_active_skill must be false")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {
		"ok": true,
		"data": {
			"applies_to": &"normal_attack",
			"requires_strict_height_advantage": true,
			"extra_attack_offsets": (offsets.get("data", []) as Array).duplicate(),
			"damage_bonus": 0,
			"affects_boss_core": false,
			"affects_active_skill": false,
		},
	}


func _parse_offsets(raw: Variant) -> Dictionary:
	var expected: Array[Vector2i] = [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2)]
	if not raw is Array or (raw as Array).size() != expected.size():
		return {"ok": false}
	var parsed: Array[Vector2i] = []
	for item in raw as Array:
		if not item is Array or (item as Array).size() != 2:
			return {"ok": false}
		if not _is_int_like((item as Array)[0]) or not _is_int_like((item as Array)[1]):
			return {"ok": false}
		parsed.append(Vector2i(int((item as Array)[0]), int((item as Array)[1])))
	if parsed != expected:
		return {"ok": false}
	return {"ok": true, "data": parsed}


func _is_int_like(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, roundf(value)))


func is_unit_eligible(card_id: StringName, card_tags: Array[String]) -> bool:
	if not _enabled:
		return false
	for raw_tag in card_tags:
		if _denied_tags.has(StringName(raw_tag)):
			return false
	var profile := get_unit_profile(card_id)
	return bool(profile.get("can_garrison", false)) and profile.get("size_class", &"") == &"normal"


func get_unit_profile(card_id: StringName) -> Dictionary:
	if not _enabled:
		return {}
	if _unit_overrides.has(card_id):
		return (_unit_overrides[card_id] as Dictionary).duplicate(true)
	return _default_unit_profile.duplicate(true)


func get_slot_profile(structure_profile_id: StringName, slot_id: StringName) -> Dictionary:
	var key := StringName("%s:%s" % [structure_profile_id, slot_id])
	if not _structure_slots.has(key):
		return {}
	return (_structure_slots[key] as Dictionary).duplicate(true)


func get_range_profile(profile_id: StringName) -> Dictionary:
	if profile_id == &"none" or not _range_profiles.has(profile_id):
		return {}
	return (_range_profiles[profile_id] as Dictionary).duplicate(true)


func get_fallback_relative_order() -> Array[StringName]:
	return _fallback_relative_order.duplicate()


func to_snapshot() -> Dictionary:
	return {
		"schema_version": schema_version,
		"enabled": _enabled,
		"used_fallback": used_fallback,
		"validation_errors": validation_errors.duplicate(),
		"default_unit_profile": _default_unit_profile.duplicate(true),
		"denied_tags": _denied_tags.duplicate(),
		"unit_overrides": _unit_overrides.duplicate(true),
		"structure_slots": _structure_slots.duplicate(true),
		"range_profiles": _range_profiles.duplicate(true),
		"fallback_landing_relative_order": _fallback_relative_order.duplicate(),
	}
