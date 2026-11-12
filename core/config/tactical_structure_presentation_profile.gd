extends RefCounted
## Presentation-only profile.  Rule identity and legality never enter this object.

const REQUIRED_ASSET_FIELDS := [&"asset_id", &"wrapper_scene", &"socket_schema_version", &"bounds_profile", &"preview_mode", &"state_variant_mode", &"lod_policy"]
const DEFAULT_ASSETS := {
	&"p05_foundation": {"asset_id":"procedural_foundation","wrapper_scene":"","socket_schema_version":1,"bounds_profile":"foundation","preview_mode":"hologram","state_variant_mode":"snapshot","lod_policy":"shared"},
	&"p08_fortification": {"asset_id":"procedural_fortification","wrapper_scene":"","socket_schema_version":1,"bounds_profile":"fortification","preview_mode":"hologram","state_variant_mode":"snapshot","lod_policy":"shared"},
	&"p13_heat_sink": {"asset_id":"procedural_heat_sink","wrapper_scene":"","socket_schema_version":1,"bounds_profile":"heat_sink","preview_mode":"hologram","state_variant_mode":"foundation_snapshot","lod_policy":"shared"},
	&"p16_containment_wall": {"asset_id":"procedural_containment_wall","wrapper_scene":"","socket_schema_version":1,"bounds_profile":"containment_wall","preview_mode":"oriented_hologram","state_variant_mode":"foundation_snapshot","lod_policy":"shared"},
	&"p19_core_cathedral": {"asset_id":"procedural_core_cathedral","wrapper_scene":"","socket_schema_version":1,"bounds_profile":"core_cathedral","preview_mode":"replacement_comparison","state_variant_mode":"foundation_snapshot","lod_policy":"shared"}
}
const ALLOWED_BOUNDS_PROFILES := ["foundation", "fortification", "heat_sink", "containment_wall", "core_cathedral"]
const DEFAULT_TOKENS := {&"source_seal": &"construction_seal", &"source_arc": &"construction_arc", &"selection_legal": &"legal_outline", &"selection_replacement": &"replacement_outline", &"selection_invalid": &"invalid_outline", &"selection_pending": &"pending_outline", &"foundation_stable": &"stability_lock", &"foundation_waiting": &"dashed_foundation", &"foundation_active": &"countdown_crack", &"foundation_due": &"terminal_fracture", &"reduced_motion_outline": &"static_outline"}
const DEFAULT_PREVIEW := {&"legal": &"legal_hologram", &"replacement": &"replacement_hologram", &"invalid": &"invalid_hologram", &"pending": &"pending_hologram", &"compatibility_fallback": &"opaque_outline"}

var _assets: Dictionary = DEFAULT_ASSETS.duplicate(true)
var _tokens: Dictionary = DEFAULT_TOKENS.duplicate(true)
var _preview: Dictionary = DEFAULT_PREVIEW.duplicate(true)
var _geometry := {&"core_footprint_ratio":0.70, &"wall_length_ratio":0.84, &"wall_thickness_ratio":0.10, &"foundation_height_step_ratio":0.68, &"fortification_height_step_ratio":1.28, &"heat_sink_core_ratio":0.42, &"cooling_ring_ratio":0.62, &"containment_anchor_ratio":0.34, &"cathedral_column_ratio":0.40, &"cathedral_core_ratio":0.56}
var _timing := {&"hover_snap_seconds":0.10, &"fade_seconds":0.12, &"reduced_motion_seconds":0.0, &"assembly_seconds":0.24, &"hit_seconds":0.10, &"breach_seconds":0.16, &"core_destroy_seconds":0.28}
var _used_fallback := false
var _validation_errors: Array[String] = []
var _warned: Dictionary = {}
static var _reported_warning_keys: Dictionary = {}

func _init(table: Dictionary = {}, fallback_used: bool = false, errors: Array[String] = []) -> void:

	_used_fallback = fallback_used
	_validation_errors = errors.duplicate()
	if table.is_empty():
		return
	if int(table.get("schema_version", 0)) != 1:
		_used_fallback = true
		_warn_once(&"schema", "Presentation schema rejected; using procedural defaults.")
		return
	var raw_assets: Variant = table.get("assets", {})
	if not raw_assets is Dictionary:
		_used_fallback = true
		_warn_once(&"assets", "assets table is invalid; using procedural defaults.")
		return
	var assets := raw_assets as Dictionary
	for profile_id in DEFAULT_ASSETS:
		var raw_incoming: Variant = assets.get(profile_id, {})
		var safe: Dictionary = DEFAULT_ASSETS[profile_id].duplicate(true)
		if not raw_incoming is Dictionary:
			_warn_once(&"assets:" + StringName(profile_id), "assets.%s is invalid; using procedural greybox." % profile_id)
			_assets[profile_id] = safe
			continue
		var incoming := raw_incoming as Dictionary
		if _contains_rule_field(incoming):
			_warn_once(&"rule:" + StringName(profile_id), "Presentation rule field rejected; using procedural greybox.")
			_assets[profile_id] = safe
			continue
		for field in REQUIRED_ASSET_FIELDS:
			if not incoming.has(field): continue
			var value: Variant = incoming[field]
			if field == &"socket_schema_version":
				if (value is int or value is float) and is_equal_approx(float(value), roundf(float(value))): safe[field] = int(value)
				else: _warn_once(&"assets:%s:%s" % [profile_id, field], "assets.%s.%s is invalid; default retained." % [profile_id, field])
			elif value is String and not str(value).is_empty():
				safe[field] = value
			else:
				_warn_once(&"assets:%s:%s" % [profile_id, field], "assets.%s.%s is invalid; default retained." % [profile_id, field])
		if int(safe["socket_schema_version"]) != 1 or not String(safe["bounds_profile"]) in ALLOWED_BOUNDS_PROFILES or not ResourceLoader.exists(str(safe["wrapper_scene"])):
			safe["wrapper_scene"] = ""
			_warn_once(&"wrapper:" + StringName(profile_id), "Structure wrapper unavailable; using procedural greybox.")
		_assets[profile_id] = safe
	_load_tokens(table.get("tokens", {}))
	_load_preview(table.get("preview", {}))
	_load_numbers(table.get("geometry", {}), _geometry, {&"core_footprint_ratio": [0.10, 0.74], &"wall_length_ratio": [0.10, 0.88], &"wall_thickness_ratio": [0.02, 0.12], &"foundation_height_step_ratio": [0.10, 0.70], &"fortification_height_step_ratio": [0.10, 1.35], &"heat_sink_core_ratio": [0.20, 0.65], &"cooling_ring_ratio": [0.35, 0.85], &"containment_anchor_ratio": [0.20, 0.60], &"cathedral_column_ratio": [0.20, 0.70], &"cathedral_core_ratio": [0.30, 0.74]}, &"geometry")
	_load_numbers(table.get("timing", {}), _timing, {&"hover_snap_seconds": [0.0, 1.0], &"fade_seconds": [0.0, 1.0], &"reduced_motion_seconds": [0.0, 0.0], &"assembly_seconds": [0.0, 2.0], &"hit_seconds": [0.0, 1.0], &"breach_seconds": [0.0, 1.0], &"core_destroy_seconds": [0.0, 2.0]}, &"timing")

func _load_tokens(raw: Variant) -> void:

	if not raw is Dictionary:
		_warn_once(&"tokens", "tokens table is invalid; defaults retained.")
		return
	var values := raw as Dictionary
	for key in _tokens:
		if not values.has(key): continue
		if values[key] is String and not str(values[key]).is_empty(): _tokens[key] = StringName(values[key])
		else: _warn_once(&"tokens:" + StringName(key), "tokens.%s is invalid; default retained." % key)

func _load_preview(raw: Variant) -> void:

	if not raw is Dictionary:
		_warn_once(&"preview", "preview table is invalid; defaults retained.")
		return
	var values := raw as Dictionary
	for key in _preview:
		if not values.has(key): continue
		if values[key] is String and not str(values[key]).is_empty(): _preview[key] = StringName(values[key])
		else: _warn_once(&"preview:" + StringName(key), "preview.%s is invalid; default retained." % key)

func _load_numbers(raw: Variant, target: Dictionary, ranges: Dictionary, section: StringName) -> void:

	if not raw is Dictionary:
		_warn_once(section, "%s table is invalid; defaults retained." % section)
		return
	var values := raw as Dictionary
	for key in target:
		if not values.has(key): continue
		var value: Variant = values.get(key, null)
		var span: Array = ranges[key]
		if value is int or value is float:
			var number := float(value)
			if number >= float(span[0]) and number <= float(span[1]): target[key] = number
			else: _warn_once(&"%s:%s" % [section, key], "%s.%s is out of range; default retained." % [section, key])
		else:
			_warn_once(&"%s:%s" % [section, key], "%s.%s is invalid; default retained." % [section, key])

func _warn_once(key: StringName, message: String) -> void:
	if _warned.has(key) or _reported_warning_keys.has(key): return
	_warned[key] = true
	_reported_warning_keys[key] = true
	push_warning("[CONFIG ERROR] [STRUCTURE PRESENTATION] %s" % message)

static func get_reported_warning_count() -> int:

	return _reported_warning_keys.size()

func _contains_rule_field(value: Variant) -> bool:

	const FORBIDDEN := ["integrity", "blocking", "cost", "reason_code", "reason_codes", "card_condition", "card_conditions", "replacement_permission", "replacement_permissions", "allowed_height", "allowed_heights", "minimum_foundation_height", "auto_raise_from_height"]
	if value is Dictionary:
		for raw_key in (value as Dictionary).keys():
			var key := str(raw_key).to_lower()
			if key in FORBIDDEN or key.begins_with("allowed_height") or key.contains("integrity") or key.contains("replacement_permission"): return true
			if _contains_rule_field((value as Dictionary)[raw_key]): return true
	elif value is Array:
		for child in value:
			if _contains_rule_field(child): return true
	return false

func get_asset(profile_id: StringName) -> Dictionary: return (_assets.get(profile_id, DEFAULT_ASSETS.get(profile_id, {})) as Dictionary).duplicate(true)
func get_preview_token(state: StringName) -> StringName: return _preview.get(state, _preview[&"invalid"])
func get_source_seal_token() -> StringName: return _tokens[&"source_seal"]
func get_source_arc_token() -> StringName: return _tokens[&"source_arc"]
func get_token(token: StringName) -> StringName: return _tokens.get(token, &"")
func get_geometry_ratio(key: StringName) -> float: return float(_geometry.get(key, 0.0))
func get_timing_seconds(key: StringName) -> float: return float(_timing.get(key, 0.0))
func used_fallback() -> bool: return _used_fallback
func get_validation_errors() -> Array[String]: return _validation_errors.duplicate()
