extends RefCounted
class_name ODFeedbackLedger
## Bounded, query-only event ledger for committed OD flow facts.
## The ledger never calculates or mutates gameplay state.

const DEFAULT_CAPACITY := 256

var _snapshot: RefCounted = null
var _capacity := DEFAULT_CAPACITY
var _events: Array[Dictionary] = []
var _sequence := 0
var _committed_keys: Dictionary = {}
var _transaction_ordinals: Dictionary = {}


func configure(snapshot: RefCounted) -> void:
	_snapshot = snapshot
	_capacity = clampi(int(snapshot.call("get_event_buffer_capacity")) if snapshot != null and snapshot.has_method("get_event_buffer_capacity") else DEFAULT_CAPACITY, 32, 2048)
	_trim_to_capacity()


func append_committed_event(event_kind: StringName, transaction_id: StringName, payload: Dictionary) -> Dictionary:
	var source_id := StringName(payload.get("source_id", &"unclassified"))
	var occurrence_id := StringName(payload.get("occurrence_id", &"0"))
	var dedupe_key := ""
	if transaction_id != &"":
		dedupe_key = "%s|%s|%s|%s" % [str(transaction_id), str(event_kind), str(source_id), str(occurrence_id)]
		if _committed_keys.has(dedupe_key):
			var duplicate: Dictionary = (_committed_keys[dedupe_key] as Dictionary).duplicate(true)
			duplicate["deduplicated"] = true
			return duplicate

	_sequence += 1
	var tx_key := str(transaction_id)
	var ordinal := int(_transaction_ordinals.get(tx_key, 0)) + 1
	_transaction_ordinals[tx_key] = ordinal
	var event := _make_event_defaults()
	for key in payload:
		event[key] = payload[key]
	event["schema_version"] = 1
	event["event_kind"] = event_kind
	event["transaction_id"] = transaction_id
	event["sequence"] = _sequence
	event["event_id"] = StringName("odfb:%s:%s:%s:%d" % [
		_ascii_id(tx_key if not tx_key.is_empty() else "no_tx"),
		_ascii_id(str(event_kind)),
		_ascii_id(str(source_id)),
		ordinal,
	])
	event["deduplicated"] = false
	_events.append(event.duplicate(true))
	if not dedupe_key.is_empty():
		_committed_keys[dedupe_key] = event.duplicate(true)
	_trim_to_capacity()
	return event.duplicate(true)


func get_events_after(after_sequence: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in _events:
		if int(event.get("sequence", 0)) > after_sequence:
			result.append(event.duplicate(true))
	return result


func get_latest_sequence() -> int:
	return _sequence


func get_snapshot() -> Dictionary:
	return {
		"latest_sequence": _sequence,
		"buffered_event_count": _events.size(),
		"event_buffer_capacity": _capacity,
		"events": get_events_after(0),
	}


func clear() -> void:
	_events.clear()
	_committed_keys.clear()
	_transaction_ordinals.clear()
	_sequence = 0


func _make_event_defaults() -> Dictionary:
	return {
		"schema_version": 1,
		"event_id": &"",
		"event_kind": &"",
		"transaction_id": &"",
		"sequence": 0,
		"actor_side": &"player",
		"source_kind": &"unclassified",
		"source_id": &"unclassified",
		"source_family": &"unclassified",
		"source_policy": &"bounded_existing",
		"classified": false,
		"raw_heat_delta": 0,
		"saturation_penalty": 0,
		"applied_heat_delta": 0,
		"wasted_at_cap": 0,
		"heat_before": 0,
		"heat_after": 0,
		"charge_before": 0,
		"charge_after": 0,
		"layer_before": 1,
		"layer_after": 1,
		"zone_before": &"Calm",
		"zone_after": &"Calm",
		"depth_before": 0,
		"depth_after": 0,
		"saturation_step_before": 0,
		"saturation_step_after": 0,
		"relief_action_family": &"",
		"conversion_reason": &"",
		"board_cell": Vector2i(-1, -1),
		"target_cell": Vector2i(-1, -1),
		"piece_type": &"",
		"presentation_tier": &"micro",
		"coalescing_key": &"",
		"occurrence_id": &"0",
	}


func _trim_to_capacity() -> void:
	while _events.size() > _capacity:
		_events.pop_front()


func _ascii_id(value: String) -> String:
	var result := ""
	for i in range(value.length()):
		var code := value.unicode_at(i)
		var valid := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [45, 46, 58, 95]
		result += value[i] if valid else "_"
	return result if not result.is_empty() else "unknown"
