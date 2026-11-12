extends RefCounted
class_name ODFlowFeedbackSnapshot
## Immutable Phase 27K-R1-A descriptor snapshot.
## It classifies Heat sources for audit/presentation only and never calculates
## Heat, Charge, Layer, Depth, costs, or legality.

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
		"event_buffer_capacity": 256,
		"saturation": {"enabled": false, "repeat_penalty": [0, 1, 2]},
		"policies": ["saturable", "bounded_existing", "unsaturated_pressure", "conversion", "cooling"],
		"card_base_heat_families": {},
		"system_sources": [],
		"dynamic_source_rules": {},
		"event_tiers": {},
		"coalescing": {"key_format": "{event_kind}|{source_family}"},
	}, true, errors)


func is_fallback() -> bool:
	return _used_fallback


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func to_snapshot() -> Dictionary:
	return _values.duplicate(true)


func get_event_buffer_capacity() -> int:
	return clampi(int(_values.get("event_buffer_capacity", 256)), 32, 2048)


func is_saturation_enabled() -> bool:
	return bool((_values.get("saturation", {}) as Dictionary).get("enabled", false))


func get_card_base_descriptor(card_id: String) -> Dictionary:
	var clean_id := card_id.strip_edges()
	var families: Dictionary = _values.get("card_base_heat_families", {})
	var family := str(families.get(clean_id, ""))
	if family.is_empty():
		return _unclassified(&"card_base", StringName("base_card:%s" % clean_id))
	return {
		"classified": true,
		"source_kind": &"card_base",
		"source_id": StringName("base_card:%s" % clean_id),
		"source_family": StringName(family),
		"source_policy": &"saturable",
		"presentation_tier": &"minor",
		"card_id": clean_id,
	}


func get_source_descriptor(source_kind: StringName, source_id: StringName, card_id: String = "") -> Dictionary:
	if source_kind == &"card_base" or str(source_id).begins_with("base_card:"):
		var resolved_card := card_id
		if resolved_card.is_empty() and str(source_id).begins_with("base_card:"):
			resolved_card = str(source_id).trim_prefix("base_card:")
		return get_card_base_descriptor(resolved_card)
	for raw in _values.get("system_sources", []):
		if raw is Dictionary and StringName(raw.get("source_id", &"")) == source_id:
			var desc: Dictionary = raw.duplicate(true)
			desc["classified"] = true
			desc["source_kind"] = StringName(desc.get("source_kind", source_kind))
			desc["source_id"] = source_id
			desc["source_family"] = StringName(desc.get("source_family", &""))
			desc["source_policy"] = StringName(desc.get("source_policy", &""))
			desc["presentation_tier"] = StringName(desc.get("presentation_tier", &"micro"))
			return desc
	var dynamic_rules: Dictionary = _values.get("dynamic_source_rules", {})
	var rule: Dictionary = dynamic_rules.get(str(source_kind), {})
	if not rule.is_empty():
		var prefix := str(rule.get("prefix", ""))
		var suffix := str(source_id).trim_prefix(prefix) if str(source_id).begins_with(prefix) else ""
		if not prefix.is_empty() and not suffix.is_empty():
			return {
				"classified": true,
				"source_kind": source_kind,
				"source_id": source_id,
				"source_family": StringName(rule.get("source_family", &"")),
				"source_policy": StringName(rule.get("source_policy", &"")),
				"presentation_tier": StringName(rule.get("presentation_tier", &"micro")),
			}
	return _unclassified(source_kind, source_id)


func get_event_tier(event_kind: StringName) -> StringName:
	return StringName((_values.get("event_tiers", {}) as Dictionary).get(str(event_kind), "micro"))


func get_coalescing_key(event_kind: StringName, source_family: StringName) -> StringName:
	var template := str((_values.get("coalescing", {}) as Dictionary).get("key_format", "{event_kind}|{source_family}"))
	return StringName(template.replace("{event_kind}", str(event_kind)).replace("{source_family}", str(source_family)))


func _unclassified(source_kind: StringName, source_id: StringName) -> Dictionary:
	return {
		"classified": false,
		"source_kind": source_kind,
		"source_id": source_id,
		"source_family": &"unclassified",
		"source_policy": &"bounded_existing",
		"presentation_tier": &"micro",
	}
