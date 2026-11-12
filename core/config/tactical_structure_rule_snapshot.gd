extends RefCounted
class_name TacticalStructureRuleSnapshot

## Elevated Grid Phase C — immutable structure rule snapshot.
## Pure P05/P08/P13/P16/P19 profile queries. Created once by GameConfig and injected into BattleSystem.
## Contains no Charge, OD, Depth, card cost or unit state. Getter results are deep copies.

const PLAYER_FORWARD: StringName = &"north"
const BOSS_FORWARD: StringName = &"south"

var schema_version: int = 1
var used_fallback := false
var validation_errors: Array[String] = []
var _profiles: Dictionary = {}


func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	used_fallback = fallback_used
	validation_errors = errors.duplicate()
	if values.is_empty():
		return
	schema_version = int(values.get("schema_version", 1))
	var profiles_raw: Dictionary = values.get("profiles", {})
	if not profiles_raw is Dictionary:
		return
	for profile_id in profiles_raw:
		var parsed: Dictionary = _parse_profile(StringName(str(profile_id)), profiles_raw[profile_id])
		if bool(parsed.get("ok", false)):
			_profiles[StringName(str(profile_id))] = parsed["data"]
		else:
			for error in parsed.get("errors", []):
				var msg := "[CONFIG ERROR] tactical_structure_rules profile '%s': %s" % [profile_id, str(error)]
				if not validation_errors.has(msg):
					validation_errors.append(msg)


static func default_snapshot(errors: Array[String] = []) -> RefCounted:
	var inst = new()
	inst.used_fallback = true
	inst.validation_errors = errors.duplicate()
	return inst


func _parse_profile(profile_id: StringName, raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "errors": ["profile is not a Dictionary"]}
	var errors: Array[String] = []
	var card_id: String = str(raw.get("card_id", ""))
	var allowed_heights: Array[int] = _to_int_array(raw.get("allowed_heights", []))
	var auto_raise: int = _safe_int(raw.get("auto_raise_from_height", -999), -999)
	var min_foundation: int = _safe_int(raw.get("minimum_foundation_height", -999), -999)
	var core_integrity: int = _safe_int(raw.get("core_integrity", -999), -999)
	var reserved_slots: int = _safe_int(raw.get("reserved_garrison_slots", -999), -999)
	var modules_raw: Variant = raw.get("modules", [])
	var garrison_raw: Variant = raw.get("garrison_slots", [])
	var stabilizes_raw: Variant = raw.get("stabilizes_terrain", false)
	var orientation_raw: Variant = raw.get("orientation_mode", "")
	var replacement_raw: Variant = raw.get("replacement_profile_ids", [])
	var requires_replacement_raw: Variant = raw.get("requires_replacement", false)
	var requires_stable_raw: Variant = raw.get("requires_stable_replacement", false)
	var requires_empty_garrison_raw: Variant = raw.get("requires_empty_garrison", false)

	if profile_id == &"p05_foundation":
		if card_id != "P05":
			errors.append("card_id must be P05")
		if not _int_array_equals(allowed_heights, [0, 1]):
			errors.append("allowed_heights must be [0,1]")
		if auto_raise != 0:
			errors.append("auto_raise_from_height must be 0")
		if min_foundation != 1:
			errors.append("minimum_foundation_height must be 1")
		if core_integrity != 2:
			errors.append("core_integrity must be 2")
		if reserved_slots != 0:
			errors.append("reserved_garrison_slots must be 0")
		if not modules_raw is Array or not (modules_raw as Array).is_empty():
			errors.append("modules must be empty")
		if raw.has("garrison_slots"):
			if not garrison_raw is Array:
				errors.append("garrison_slots must be an Array")
			elif not (garrison_raw as Array).is_empty():
				errors.append("garrison_slots must be empty")
	elif profile_id == &"p08_fortification":
		if card_id != "P08":
			errors.append("card_id must be P08")
		if not _int_array_equals(allowed_heights, [1]):
			errors.append("allowed_heights must be [1]")
		if auto_raise != -1:
			errors.append("auto_raise_from_height must be -1")
		if min_foundation != 1:
			errors.append("minimum_foundation_height must be 1")
		if core_integrity != 3:
			errors.append("core_integrity must be 3")
		if reserved_slots != 1:
			errors.append("reserved_garrison_slots must be 1")
		errors.append_array(_validate_garrison_slots(garrison_raw))
		errors.append_array(_validate_p08_modules(modules_raw))
	elif profile_id == &"p13_heat_sink":
		if card_id != "P13":
			errors.append("card_id must be P13")
		if not _int_array_equals(allowed_heights, [0, 1]):
			errors.append("allowed_heights must be [0,1]")
		if auto_raise != -1:
			errors.append("auto_raise_from_height must be -1")
		if min_foundation != 0:
			errors.append("minimum_foundation_height must be 0")
		if core_integrity != 2:
			errors.append("core_integrity must be 2")
		if not raw.has("stabilizes_terrain") or not stabilizes_raw is bool or not bool(stabilizes_raw):
			errors.append("stabilizes_terrain must be true")
		if reserved_slots != 0:
			errors.append("reserved_garrison_slots must be 0")
		errors.append_array(_validate_empty_garrison(garrison_raw))
		if not modules_raw is Array or not (modules_raw as Array).is_empty():
			errors.append("modules must be empty")
	elif profile_id == &"p16_containment_wall":
		if card_id != "P16":
			errors.append("card_id must be P16")
		if not _int_array_equals(allowed_heights, [0, 1]):
			errors.append("allowed_heights must be [0,1]")
		if auto_raise != -1:
			errors.append("auto_raise_from_height must be -1")
		if min_foundation != 0:
			errors.append("minimum_foundation_height must be 0")
		if core_integrity != 2:
			errors.append("core_integrity must be 2")
		if not raw.has("stabilizes_terrain") or not stabilizes_raw is bool or bool(stabilizes_raw):
			errors.append("stabilizes_terrain must be false")
		if reserved_slots != 0:
			errors.append("reserved_garrison_slots must be 0")
		if not raw.has("orientation_mode") or not orientation_raw is String or str(orientation_raw) != "selected_edge":
			errors.append("orientation_mode must be selected_edge")
		errors.append_array(_validate_empty_garrison(garrison_raw))
		errors.append_array(_validate_p16_modules(modules_raw))
	elif profile_id == &"p19_core_cathedral":
		if card_id != "P19":
			errors.append("card_id must be P19")
		if not _int_array_equals(allowed_heights, [1]):
			errors.append("allowed_heights must be [1]")
		if auto_raise != 1:
			errors.append("auto_raise_from_height must be 1")
		if min_foundation != 2:
			errors.append("minimum_foundation_height must be 2")
		if core_integrity != 4:
			errors.append("core_integrity must be 4")
		if not raw.has("stabilizes_terrain") or not stabilizes_raw is bool or bool(stabilizes_raw):
			errors.append("stabilizes_terrain must be false")
		if reserved_slots != 0:
			errors.append("reserved_garrison_slots must be 0")
		if not raw.has("requires_replacement") or not requires_replacement_raw is bool or not bool(requires_replacement_raw):
			errors.append("requires_replacement must be true")
		errors.append_array(_validate_replacement_profiles(replacement_raw))
		if not raw.has("requires_stable_replacement") or not requires_stable_raw is bool or not bool(requires_stable_raw):
			errors.append("requires_stable_replacement must be true")
		if not raw.has("requires_empty_garrison") or not requires_empty_garrison_raw is bool or not bool(requires_empty_garrison_raw):
			errors.append("requires_empty_garrison must be true")
		errors.append_array(_validate_empty_garrison(garrison_raw))
		if not modules_raw is Array or not (modules_raw as Array).is_empty():
			errors.append("modules must be empty")
	else:
		return {"ok": false, "errors": ["unknown profile id '%s'" % profile_id]}

	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {
		"ok": true,
		"data": {
			"profile_id": profile_id,
			"card_id": card_id,
			"allowed_heights": allowed_heights,
			"auto_raise_from_height": auto_raise,
			"minimum_foundation_height": min_foundation,
			"core_integrity": core_integrity,
			"stabilizes_terrain": bool(stabilizes_raw) if stabilizes_raw is bool else false,
			"reserved_garrison_slots": reserved_slots,
			"garrison_slots": _parse_garrison_list(garrison_raw),
			"orientation_mode": StringName(str(orientation_raw)),
			"requires_replacement": bool(requires_replacement_raw) if requires_replacement_raw is bool else false,
			"replacement_profile_ids": _parse_string_name_list(replacement_raw),
			"requires_stable_replacement": bool(requires_stable_raw) if requires_stable_raw is bool else false,
			"requires_empty_garrison": bool(requires_empty_garrison_raw) if requires_empty_garrison_raw is bool else false,
			"modules": _parse_module_list(modules_raw),
		},
	}


func _int_array_equals(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


func _validate_garrison_slots(raw: Variant) -> Array[String]:
	var errs: Array[String] = []
	if not raw is Array:
		errs.append("garrison_slots must be an Array")
		return errs
	var slots: Array = raw
	if slots.size() != 1:
		errs.append("garrison_slots must contain exactly 1 descriptor")
		return errs
	var slot: Variant = slots[0]
	if not slot is Dictionary:
		errs.append("garrison slot is not a Dictionary")
		return errs
	if str((slot as Dictionary).get("slot_id", "")) != "garrison_0":
		errs.append("garrison slot_id must be garrison_0")
	if str((slot as Dictionary).get("socket_name", "")) != "Garrison0":
		errs.append("garrison socket_name must be Garrison0")
	if str((slot as Dictionary).get("slot_role", "")) != "rampart":
		errs.append("garrison slot_role must be rampart")
	var enabled: Variant = (slot as Dictionary).get("enabled", true)
	if not enabled is bool:
		errs.append("garrison enabled must be bool")
	elif bool(enabled):
		errs.append("garrison enabled must be false")
	return errs


func _validate_p08_modules(raw: Variant) -> Array[String]:
	var errs: Array[String] = []
	if not raw is Array:
		errs.append("modules must be an Array")
		return errs
	var modules: Array = raw
	var expected: Array[Dictionary] = [
		{"kind": "gatehouse", "relative_edge": "forward", "integrity": 2},
		{"kind": "wall", "relative_edge": "left", "integrity": 2},
		{"kind": "wall", "relative_edge": "right", "integrity": 2},
		{"kind": "wall", "relative_edge": "rear", "integrity": 2},
	]
	if modules.size() != expected.size():
		errs.append("modules must contain exactly 4 entries")
		return errs
	for i in range(expected.size()):
		var module: Variant = modules[i]
		var expected_module: Dictionary = expected[i]
		if not module is Dictionary:
			errs.append("module[%d] is not a Dictionary" % i)
			continue
		for key in expected_module:
			if (module as Dictionary).get(key) != expected_module[key]:
				errs.append("module[%d].%s must be %s" % [i, key, str(expected_module[key])])
	return errs


func _validate_empty_garrison(raw: Variant) -> Array[String]:
	if not raw is Array:
		return ["garrison_slots must be an Array"]
	if not (raw as Array).is_empty():
		return ["garrison_slots must be empty"]
	return []


func _validate_p16_modules(raw: Variant) -> Array[String]:
	var errs: Array[String] = []
	if not raw is Array:
		return ["modules must be an Array"]
	var modules: Array = raw
	if modules.size() != 1:
		return ["modules must contain exactly 1 selected wall"]
	if not modules[0] is Dictionary:
		return ["module[0] is not a Dictionary"]
	var module: Dictionary = modules[0]
	var expected := {"kind": "wall", "relative_edge": "selected", "integrity": 2}
	for key in expected:
		if module.get(key) != expected[key]:
			errs.append("module[0].%s must be %s" % [key, str(expected[key])])
	return errs


func _validate_replacement_profiles(raw: Variant) -> Array[String]:
	if not raw is Array:
		return ["replacement_profile_ids must be an Array"]
	var values: Array = raw
	if values.size() != 2:
		return ["replacement_profile_ids must be [p05_foundation,p08_fortification]"]
	if not values[0] is String or not values[1] is String:
		return ["replacement_profile_ids entries must be Strings"]
	if str(values[0]) != "p05_foundation" or str(values[1]) != "p08_fortification":
		return ["replacement_profile_ids must be [p05_foundation,p08_fortification]"]
	return []


func _parse_garrison_list(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				result.append(item.duplicate(true))
	return result


func _parse_string_name_list(raw: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if raw is Array:
		for item in raw:
			if item is String or item is StringName:
				result.append(StringName(str(item)))
	return result


func _parse_module_list(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				var copy: Dictionary = (item as Dictionary).duplicate(true)
				if copy.has("integrity") and _is_int_like(copy["integrity"]):
					copy["integrity"] = int(copy["integrity"])
				result.append(copy)
	return result


func _to_int_array(raw: Variant) -> Array[int]:
	var result: Array[int] = []
	if raw is Array:
		for value in raw:
			if _is_int_like(value):
				result.append(int(value))
	return result


func _is_int_like(val) -> bool:
	if val is int:
		return true
	if val is float:
		return val == floor(val)
	return false


func _safe_int(val, default: int = 0) -> int:
	if val is int:
		return val
	if val is float:
		return int(val)
	return default


## 按 card_id 查询 profile；未知卡牌返回空，不猜测。
func has_profile(card_id: String) -> bool:
	return not get_profile(card_id).is_empty()


func get_profile(card_id: String) -> Dictionary:
	for profile_id in _profiles:
		var data: Dictionary = _profiles[profile_id]
		if str(data.get("card_id", "")) == card_id:
			return data.duplicate(true)
	return {}


func get_profile_by_id(profile_id: StringName) -> Dictionary:
	if not _profiles.has(profile_id):
		return {}
	return (_profiles[profile_id] as Dictionary).duplicate(true)


func get_allowed_heights(profile_id: StringName) -> Array[int]:
	var data: Dictionary = get_profile_by_id(profile_id)
	if data.is_empty():
		return []
	return (data.get("allowed_heights", []) as Array).duplicate()


func get_core_integrity(profile_id: StringName) -> int:
	var data: Dictionary = get_profile_by_id(profile_id)
	return int(data.get("core_integrity", 0))


func get_garrison_slots(profile_id: StringName) -> Array[Dictionary]:
	var data: Dictionary = get_profile_by_id(profile_id)
	if data.is_empty():
		return []
	return (data.get("garrison_slots", []) as Array[Dictionary]).duplicate(true)


func get_modules(profile_id: StringName) -> Array[Dictionary]:
	var data: Dictionary = get_profile_by_id(profile_id)
	if data.is_empty():
		return []
	return (data.get("modules", []) as Array[Dictionary]).duplicate(true)


func get_replacement_profile_ids(profile_id: StringName) -> Array[StringName]:
	var data: Dictionary = get_profile_by_id(profile_id)
	if data.is_empty():
		return []
	var result: Array[StringName] = []
	for value in data.get("replacement_profile_ids", []):
		result.append(StringName(str(value)))
	return result


func profile_stabilizes_terrain(profile_id: StringName) -> bool:
	var data: Dictionary = get_profile_by_id(profile_id)
	return bool(data.get("stabilizes_terrain", false))


func get_forward_edge(owner_side: StringName) -> StringName:
	return BOSS_FORWARD if StringName(str(owner_side)) == &"boss" else PLAYER_FORWARD


## relative edge → absolute board edge。player forward=north；boss forward=south。
## 绝对方向（north/east/south/west）原样返回。
func normalize_relative_edge(owner_side: StringName, relative_edge: StringName) -> StringName:
	var is_boss := StringName(str(owner_side)) == &"boss"
	match relative_edge:
		&"forward":
			return &"south" if is_boss else &"north"
		&"rear":
			return &"north" if is_boss else &"south"
		&"left":
			return &"east" if is_boss else &"west"
		&"right":
			return &"west" if is_boss else &"east"
		_:
			return relative_edge
