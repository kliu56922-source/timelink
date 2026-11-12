extends Node
class_name BattlePresentationDirector
## Read-only choreography coordinator for committed battle facts.
## This node may schedule presentation work, but never mutates battle rules.

signal cue_started(cue: Dictionary)
signal cue_phase_changed(cue_id: StringName, phase: StringName)
signal cue_finished(cue: Dictionary)
signal presentation_busy_changed(busy: bool, reason: StringName)

const PHASE_ORDER: Array[StringName] = [&"select", &"commit", &"convey", &"resolve"]
const LANE_NAMES: Array[StringName] = [&"engine_lane", &"board_lane", &"card_lane", &"audio_lane"]
const RELEASE_END_EVENTS: Array[StringName] = [&"release_committed", &"release_cancelled"]
const RELEASE_EVENT_KINDS: Array[StringName] = [
	&"release_started", &"heat_converted", &"layer_advanced", &"zone_changed",
	&"release_committed", &"release_cancelled",
]

var _scene_ref: Node = null
var _context_ref: Node = null
var _profile: RefCounted = null
var _dependencies: Dictionary = {}

var _pending_by_transaction: Dictionary = {}
var _scheduled_transactions: Dictionary = {}
var _consumed_event_ids: Dictionary = {}
var _major_queue: Array[Dictionary] = []
var _light_queue: Array[Dictionary] = []
var _active_cue: Dictionary = {}
var _active_phase: StringName = &""
var _lane_owner: Dictionary = {
	&"engine_lane": &"",
	&"board_lane": &"",
	&"card_lane": &"",
	&"audio_lane": &"",
}
var _generation := 0
var _busy := false
var _runner_scheduled := false
var _cue_serial := 0
var _played_count := 0
var _finished_history: Array[Dictionary] = []
var _reduced_motion := false
var _fast_mode := false
var _coalesced_cue_count := 0
var _active_duration_scale := 1.0
var _auto_fast_active := false
var _dropped_cue_count := 0


func configure(scene_ref: Node, context_ref: Node, profile: RefCounted, dependencies: Dictionary) -> void:
	_scene_ref = scene_ref
	_context_ref = context_ref
	_profile = profile
	_dependencies = dependencies.duplicate(true)
	if _profile != null:
		_reduced_motion = bool(_profile.call("is_reduced_motion_default")) if _profile.has_method("is_reduced_motion_default") else false
		_fast_mode = bool(_profile.call("is_fast_mode_default")) if _profile.has_method("is_fast_mode_default") else false


func consume_od_event(event: Dictionary) -> void:
	var copied := event.duplicate(true)
	var event_id := StringName(copied.get("event_id", &""))
	if event_id != &"" and _consumed_event_ids.has(event_id):
		return
	if event_id != &"":
		_consumed_event_ids[event_id] = true

	var transaction_id := StringName(copied.get("transaction_id", &""))
	if transaction_id == &"":
		present_committed_action({
			"action_family": _family_for_event(copied),
			"tier": _safe_tier(StringName(copied.get("presentation_tier", &"micro")), false),
			"transaction_id": &"",
			"events": [copied],
			"event_ids": [event_id] if event_id != &"" else [],
			"lanes": _lanes_for_event(copied),
		})
		return

	var pending: Array = _pending_by_transaction.get(transaction_id, [])
	pending.append(copied)
	_pending_by_transaction[transaction_id] = pending
	var event_kind := StringName(copied.get("event_kind", &""))
	if event_kind in RELEASE_END_EVENTS:
		_schedule_transaction_seal(transaction_id)
	elif not event_kind in RELEASE_EVENT_KINDS:
		_schedule_transaction_seal(transaction_id)


func present_committed_action(action_fact: Dictionary) -> void:
	var cue := action_fact.duplicate(true)
	var transaction_id := StringName(cue.get("transaction_id", &""))
	var requested_tier := StringName(cue.get("tier", &"micro"))
	cue["tier"] = _safe_tier(requested_tier, transaction_id != &"")
	cue["transaction_id"] = transaction_id
	cue["action_family"] = StringName(cue.get("action_family", &"generic"))
	cue["lanes"] = _sanitize_lanes(cue.get("lanes", []))
	cue["events"] = (cue.get("events", []) as Array).duplicate(true)
	cue["event_ids"] = (cue.get("event_ids", []) as Array).duplicate(true)
	cue["status"] = StringName(cue.get("status", &"committed"))
	_inherit_source_identity_from_events(cue)
	cue["queued_at_msec"] = Time.get_ticks_msec()
	cue["coalesced_count"] = 1
	var transaction_ids: Array[StringName] = []
	if transaction_id != &"":
		transaction_ids.append(transaction_id)
	cue["transaction_ids"] = transaction_ids
	cue["phase_trace"] = []
	cue["generation"] = _generation
	if _try_coalesce_micro(cue):
		_schedule_runner()
		return
	_cue_serial += 1
	cue["cue_id"] = StringName("presentation:%d:%d" % [_generation, _cue_serial])
	if StringName(cue.get("tier", &"micro")) == &"major":
		_major_queue.append(cue)
	else:
		_light_queue.append(cue)
	_schedule_runner()


func play_monster_action(action_kind: StringName, action_fact: Dictionary) -> void:
	while not _active_cue.is_empty():
		await get_tree().process_frame
	var scheduled_generation := _generation
	var cue := action_fact.duplicate(true)
	cue["action_family"] = StringName("monster_%s" % str(action_kind))
	cue["action_kind"] = action_kind
	cue["tier"] = _safe_tier(StringName(cue.get("tier", &"minor")), true)
	cue["transaction_id"] = StringName(cue.get("transaction_id", StringName("monster:%s:%d" % [str(action_kind), _cue_serial + 1])))
	cue["lanes"] = _sanitize_lanes(cue.get("lanes", [&"board_lane", &"card_lane", &"audio_lane"]))
	cue["events"] = []
	cue["event_ids"] = []
	cue["phase_trace"] = []
	cue["direction_trace"] = []
	cue["generation"] = scheduled_generation
	_cue_serial += 1
	cue["cue_id"] = StringName("presentation:%d:%d" % [scheduled_generation, _cue_serial])
	_active_cue = cue.duplicate(true)
	_lock_active_pacing(StringName(cue.get("tier", &"minor")), 1)
	_active_cue["played_audio_keys"] = []
	_acquire_lanes(StringName(cue.get("cue_id", &"")), cue.get("lanes", []))
	_set_busy(true, StringName(cue.get("action_family", &"monster")))
	cue_started.emit(_active_cue.duplicate(true))
	_advance_phase(&"select")
	_advance_phase(&"commit")
	_play_monster_audio_once(action_kind, cue)
	var committed := bool(cue.get("ok", false)) and StringName(cue.get("status", &"committed")) == &"committed"
	if committed:
		_advance_phase(&"convey")
	await _dispatch_monster_presenter(action_kind, cue)
	if scheduled_generation != _generation or _active_cue.is_empty():
		return
	if committed:
		_advance_phase(&"resolve")
	_finish_active_cue(StringName(cue.get("tier", &"minor")), scheduled_generation)


func _dispatch_monster_presenter(action_kind: StringName, facts: Dictionary) -> void:
	var presenter := _dependency_object(&"monster_combat_presenter")
	if presenter == null:
		return
	match action_kind:
		&"summon":
			if presenter.has_method("play_summon_sequence"):
				await presenter.call("play_summon_sequence", facts.get("card", null), facts.duplicate(true))
		&"attack":
			if presenter.has_method("play_attack_sequence"):
				await presenter.call("play_attack_sequence", facts.duplicate(true))
		&"skill":
			if presenter.has_method("play_skill_sequence"):
				await presenter.call("play_skill_sequence", facts.get("card", null), StringName(facts.get("skill_id", &"")), facts.get("target", null), facts.duplicate(true))
		&"move":
			var tactical := _dependency_object(&"tactical_presenter")
			if tactical != null and tactical.has_method("play_committed_path"):
				var typed_path: Array[Vector2i] = []
				for raw_cell in facts.get("path_cells", []):
					if raw_cell is Vector2i:
						typed_path.append(raw_cell)
				await tactical.call("play_committed_path", typed_path, facts.get("to_cell", Vector2i(-1, -1)), float(facts.get("duration", 0.18)))


func play_generic_action(action_kind: StringName, action_fact: Dictionary) -> void:
	while not _active_cue.is_empty():
		await get_tree().process_frame
	var scheduled_generation := _generation
	var cue := action_fact.duplicate(true)
	cue["action_family"] = action_kind
	cue["action_kind"] = action_kind
	cue["tier"] = _safe_tier(StringName(cue.get("tier", &"minor")), true)
	cue["transaction_id"] = StringName(cue.get("transaction_id", StringName("generic:%s:%d" % [str(action_kind), _cue_serial + 1])))
	cue["lanes"] = _sanitize_lanes(cue.get("lanes", [&"board_lane", &"audio_lane"]))
	cue["events"] = []
	cue["event_ids"] = []
	cue["phase_trace"] = []
	cue["direction_trace"] = []
	cue["generation"] = scheduled_generation
	_cue_serial += 1
	cue["cue_id"] = StringName("presentation:%d:%d" % [scheduled_generation, _cue_serial])
	_active_cue = cue.duplicate(true)
	_lock_active_pacing(StringName(cue.get("tier", &"minor")), 1)
	_active_cue["played_audio_keys"] = []
	_acquire_lanes(StringName(cue.get("cue_id", &"")), cue.get("lanes", []))
	_set_busy(true, action_kind)
	cue_started.emit(_active_cue.duplicate(true))
	_advance_phase(&"select")
	_advance_phase(&"commit")
	_play_card_direction_phase(action_kind, &"commit", scheduled_generation)
	_play_generic_audio_once(action_kind, cue)
	var committed := bool(cue.get("ok", false)) and StringName(cue.get("status", &"committed")) == &"committed"
	if action_kind == &"counter" and not bool(cue.get("triggered", false)):
		committed = false
	if committed:
		_advance_phase(&"convey")
		var direction_conveyed := _play_card_direction_phase(action_kind, &"convey", scheduled_generation)
		if not direction_conveyed:
			_play_generic_convey(action_kind, cue, scheduled_generation)
		await _wait_presentation_slice(0.12, scheduled_generation)
		if scheduled_generation != _generation or _active_cue.is_empty():
			return
		_advance_phase(&"resolve")
		var direction_resolved := _play_card_direction_phase(action_kind, &"resolve", scheduled_generation)
		if action_kind != &"piece_building" or not direction_resolved:
			_play_generic_result(cue, scheduled_generation)
		await _wait_presentation_slice(0.12, scheduled_generation)
	if scheduled_generation != _generation or _active_cue.is_empty():
		return
	if action_kind in [&"piece_spell", &"piece_building"]:
		_cancel_card_direction_nodes(StringName("%s_settle" % str(action_kind)))
	_finish_active_cue(StringName(cue.get("tier", &"minor")), scheduled_generation)


func _play_card_direction_phase(action_kind: StringName, phase: StringName, generation: int) -> bool:
	if not action_kind in [&"piece_spell", &"piece_building"] or bool(_active_cue.get("direction_fallback_only", false)):
		return false
	var card_id := StringName(_active_cue.get("card_id", &""))
	if not _card_direction_profile_complete(card_id):
		return false
	var source: Variant = _active_cue.get("source_position", null)
	var target: Variant = _active_cue.get("target_position", null)
	if not source is Vector2 or not target is Vector2:
		return false
	if not (source as Vector2).is_finite() or not (target as Vector2).is_finite() or source == target:
		return false
	var presenter := _dependency_object(&"card_direction_presenter")
	var board_root := _dependency_object(&"board_root") as Control
	if presenter == null or board_root == null or not presenter.has_method("play_phase"):
		return false
	var phase_facts: Array[Dictionary] = [_active_cue.duplicate(true)]
	if card_id == &"P08" and phase == &"resolve":
		phase_facts.clear()
		for candidate in _active_cue.get("target_positions", []):
			if candidate is Vector2 and (candidate as Vector2).is_finite():
				var target_facts := _active_cue.duplicate(true)
				target_facts["target_position"] = candidate
				phase_facts.append(target_facts)
		var source_facts := _active_cue.duplicate(true)
		source_facts["target_position"] = source
		phase_facts.append(source_facts)
	var handled := false
	for facts in phase_facts:
		var outcome: Variant = presenter.call(
			"play_phase",
			card_id, action_kind, phase,
			facts, board_root, generation,
			{"duration": maxf(0.04, _scaled_duration(0.30)), "reduced_motion": _reduced_motion}
		)
		if not outcome is Dictionary or not bool((outcome as Dictionary).get("handled", false)):
			continue
		handled = true
		var trace: Array = _active_cue.get("direction_trace", [])
		trace.append({
			"phase": phase,
			"template": StringName((outcome as Dictionary).get("template", &"")),
			"motif": StringName((outcome as Dictionary).get("motif", &"")),
		})
		_active_cue["direction_trace"] = trace
	return handled


func _card_direction_profile_complete(card_id: StringName) -> bool:
	if card_id == &"" or _profile == null or not _profile.has_method("get_card_direction_profile"):
		return false
	var profile_value: Variant = _profile.call("get_card_direction_profile", card_id)
	if not profile_value is Dictionary:
		return false
	var direction := profile_value as Dictionary
	for key in ["template", "commit_motif", "convey_motif", "resolve_motif", "accent", "reveal_level"]:
		if str(direction.get(key, "")).is_empty():
			return false
	return true


func _cancel_card_direction_nodes(reason: StringName) -> void:
	var presenter := _dependency_object(&"card_direction_presenter")
	if presenter != null and presenter.has_method("cancel_all"):
		presenter.call("cancel_all", reason)


func _play_generic_convey(action_kind: StringName, facts: Dictionary, generation: int) -> void:
	var vfx := _dependency_object(&"battle_vfx")
	var board_root := _dependency_object(&"board_root")
	if vfx == null or board_root == null:
		return
	var source_position: Variant = facts.get("source_position", null)
	var target_position: Variant = facts.get("target_position", null)
	var building_position: Variant = target_position
	if action_kind == &"piece_building":
		building_position = source_position if source_position is Vector2 else facts.get("anchor_position", null)
	if action_kind in [&"building", &"piece_building"] and building_position is Vector2 and vfx.has_method("play_spawn_ring"):
		vfx.call("play_spawn_ring", board_root, building_position, Color(0.95, 0.68, 0.20, 0.95), maxf(0.04, _scaled_duration(0.25)), generation)
	elif action_kind == &"counter" and source_position is Vector2 and target_position is Vector2:
		if vfx.has_method("play_conduit_path"):
			var counter_points: Array[Vector2] = [source_position as Vector2, target_position as Vector2]
			vfx.call("play_conduit_path", board_root, counter_points, Color(0.20, 0.90, 0.78, 0.95), maxf(0.04, _scaled_duration(0.22)), generation, _reduced_motion)
		if vfx.has_method("play_piece_sigil"):
			vfx.call("play_piece_sigil", board_root, target_position, StringName(facts.get("piece_type", &"pawn")), Color(0.35, 1.0, 0.78, 0.95), maxf(0.04, _scaled_duration(0.22)), generation)


func _play_generic_result(facts: Dictionary, generation: int) -> void:
	var vfx := _dependency_object(&"battle_vfx")
	var board_root := _dependency_object(&"board_root")
	if vfx == null or board_root == null or not vfx.has_method("play_result_badge"):
		return
	var preferred: Variant = facts.get("target_position", facts.get("source_position", null))
	if not preferred is Vector2:
		preferred = board_root.global_position + board_root.size * 0.5 if board_root is Control else Vector2.ZERO
	var safe_position := preferred as Vector2
	var resolved: Variant = _call_dependency(&"safe_position_resolver", [Vector2(180, 42), safe_position, false])
	if resolved is Vector2:
		safe_position = resolved
	vfx.call("play_result_badge", board_root, safe_position, facts.duplicate(true), maxf(0.04, _scaled_duration(0.32)), generation)


func cancel_all(reason: StringName = &"cancel") -> void:
	_generation += 1
	_pending_by_transaction.clear()
	_scheduled_transactions.clear()
	_major_queue.clear()
	_light_queue.clear()
	_active_cue.clear()
	_active_phase = &""
	_active_duration_scale = 1.0
	_auto_fast_active = false
	_runner_scheduled = false
	_coalesced_cue_count = 0
	_dropped_cue_count = 0
	_release_all_lanes(&"")
	_set_busy(false, reason)
	_call_dependency(&"cancel_all_presenters", [reason])


func is_busy() -> bool:
	return _busy


func get_debug_snapshot() -> Dictionary:
	return {
		"generation": _generation,
		"busy": _busy,
		"pending_count": _pending_by_transaction.size(),
		"consumed_event_count": _consumed_event_ids.size(),
		"major_queue_size": _major_queue.size(),
		"light_queue_size": _light_queue.size(),
		"major_queue_depth": _major_queue.size(),
		"light_queue_depth": _light_queue.size(),
		"active_cue": _active_cue.duplicate(true),
		"active_phase": _active_phase,
		"lane_owner": _lane_owner.duplicate(true),
		"played_count": _played_count,
		"finished_history": _finished_history.duplicate(true),
		"reduced_motion": _reduced_motion,
		"fast_mode": _fast_mode,
		"coalesced_cue_count": _coalesced_cue_count,
		"auto_fast_active": _auto_fast_active,
		"active_duration_scale": _active_duration_scale,
		"dropped_cue_count": _dropped_cue_count,
	}.duplicate(true)


func build_cue_preview(action_fact: Dictionary) -> Dictionary:
	var transaction_id := StringName(action_fact.get("transaction_id", &""))
	return {
		"action_family": StringName(action_fact.get("action_family", &"generic")),
		"tier": _safe_tier(StringName(action_fact.get("tier", &"micro")), transaction_id != &""),
		"transaction_id": transaction_id,
		"lanes": _sanitize_lanes(action_fact.get("lanes", [])),
		"status": StringName(action_fact.get("status", &"committed")),
	}.duplicate(true)


func get_cleanup_snapshot() -> Dictionary:
	var tween_count := 0
	var temporary_count := 0
	var shake_count := 0
	for key in [&"battle_vfx", &"monster_combat_presenter", &"spell_activation_presenter", &"tactical_presenter", &"od_engine_greybox"]:
		var dependency := _dependency_object(key)
		if dependency == null:
			continue
		if dependency.has_method("get_active_tween_count"):
			tween_count += int(dependency.call("get_active_tween_count"))
		if dependency.has_method("get_presentation_debug_snapshot"):
			var dependency_snapshot: Variant = dependency.call("get_presentation_debug_snapshot")
			if dependency_snapshot is Dictionary:
				temporary_count += int(dependency_snapshot.get("temporary_node_count", 0))
				shake_count += int(dependency_snapshot.get("shake_count", 0))
	var all_lanes_free := true
	for owner in _lane_owner.values():
		all_lanes_free = all_lanes_free and StringName(owner) == &""
	return {
		"generation": _generation,
		"busy": _busy,
		"queue_count": _pending_by_transaction.size() + _major_queue.size() + _light_queue.size(),
		"has_active_cue": not _active_cue.is_empty(),
		"active_phase": _active_phase,
		"all_lanes_free": all_lanes_free,
		"temporary_node_count": temporary_count,
		"active_tween_count": tween_count,
		"shake_count": shake_count,
		"duration_scale": _duration_scale_for_effects(),
	}.duplicate(true)


func set_accessibility(reduced_motion: bool, fast_mode: bool) -> void:
	_reduced_motion = reduced_motion
	_fast_mode = fast_mode


func _inherit_source_identity_from_events(cue: Dictionary) -> void:
	var events: Array = cue.get("events", [])
	if events.is_empty() or not events[0] is Dictionary:
		return
	var first_event: Dictionary = events[0]
	for key in ["source_family", "card_id", "piece_type", "origin_cell", "target_cell"]:
		if not cue.has(key) and first_event.has(key):
			cue[key] = first_event[key]


func _try_coalesce_micro(incoming: Dictionary) -> bool:
	if _light_queue.is_empty() or not _micro_cue_can_coalesce(incoming):
		return false
	var tail: Dictionary = _light_queue[-1]
	if not _micro_cue_can_coalesce(tail):
		return false
	if StringName(tail.get("action_family", &"")) != StringName(incoming.get("action_family", &"")):
		return false
	for key in ["source_family", "card_id", "piece_type", "origin_cell", "target_cell"]:
		if tail.get(key, null) != incoming.get(key, null):
			return false
	if not _has_source_identity(incoming):
		return false
	var window_msec := int(round(_coalescing_window() * 1000.0))
	var previous_msec := int(tail.get("last_queued_at_msec", tail.get("queued_at_msec", 0)))
	var incoming_msec := int(incoming.get("queued_at_msec", 0))
	if incoming_msec - previous_msec > window_msec:
		return false
	_merge_micro_cue(tail, incoming)
	_light_queue[-1] = tail
	_coalesced_cue_count += int(incoming.get("coalesced_count", 1))
	return true


func _micro_cue_can_coalesce(cue: Dictionary) -> bool:
	if StringName(cue.get("tier", &"")) != &"micro":
		return false
	if StringName(cue.get("status", &"committed")) in [&"cancelled", &"rejected", &"expired"]:
		return false
	var lanes: Array = cue.get("lanes", [])
	return not &"board_lane" in lanes and not &"card_lane" in lanes


func _has_source_identity(cue: Dictionary) -> bool:
	for key in ["source_family", "card_id", "piece_type"]:
		if StringName(cue.get(key, &"")) != &"":
			return true
	return cue.has("origin_cell") or cue.has("target_cell")


func _merge_micro_cue(target: Dictionary, incoming: Dictionary) -> void:
	target["coalesced_count"] = int(target.get("coalesced_count", 1)) + int(incoming.get("coalesced_count", 1))
	target["last_queued_at_msec"] = int(incoming.get("queued_at_msec", Time.get_ticks_msec()))
	for array_key in ["event_ids", "transaction_ids"]:
		var merged_values: Array = target.get(array_key, []).duplicate()
		for value in incoming.get(array_key, []):
			if value != &"" and not value in merged_values:
				merged_values.append(value)
		target[array_key] = merged_values
	var merged_events: Array = target.get("events", []).duplicate(true)
	for event in incoming.get("events", []):
		merged_events.append((event as Dictionary).duplicate(true) if event is Dictionary else event)
	target["events"] = merged_events
	for field_name in ["raw_amount", "applied_amount", "waste_amount", "heat_delta", "shield_delta", "charge_delta"]:
		if target.has(field_name) or incoming.has(field_name):
			target[field_name] = float(target.get(field_name, 0.0)) + float(incoming.get(field_name, 0.0))
	for field_name in ["heat_after", "charge_after", "layer_after", "depth_after", "shield_after", "hp_after"]:
		if incoming.has(field_name):
			target[field_name] = incoming[field_name]


func _coalescing_window() -> float:
	if _profile != null and _profile.has_method("get_coalescing_window"):
		return maxf(0.0, float(_profile.call("get_coalescing_window")))
	return 0.04


func _schedule_transaction_seal(transaction_id: StringName) -> void:
	if _scheduled_transactions.has(transaction_id):
		return
	_scheduled_transactions[transaction_id] = _generation
	call_deferred("_seal_transaction", transaction_id, _generation)


func _seal_transaction(transaction_id: StringName, scheduled_generation: int) -> void:
	_scheduled_transactions.erase(transaction_id)
	if scheduled_generation != _generation or not _pending_by_transaction.has(transaction_id):
		return
	var events: Array = _pending_by_transaction.get(transaction_id, [])
	_pending_by_transaction.erase(transaction_id)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("sequence", 0)) < int(b.get("sequence", 0)))
	if events.is_empty():
		return
	var event_ids: Array[StringName] = []
	var release_family := false
	var cancelled := false
	for event in events:
		var event_kind := StringName((event as Dictionary).get("event_kind", &""))
		release_family = release_family or event_kind in RELEASE_EVENT_KINDS
		cancelled = cancelled or event_kind == &"release_cancelled"
		var event_id := StringName((event as Dictionary).get("event_id", &""))
		if event_id != &"":
			event_ids.append(event_id)
	var first: Dictionary = events[0]
	present_committed_action({
		"action_family": &"od_release" if release_family else _family_for_event(first),
		"tier": &"micro" if cancelled else (&"major" if release_family else StringName(first.get("presentation_tier", &"micro"))),
		"transaction_id": transaction_id,
		"events": events,
		"event_ids": event_ids,
		"lanes": LANE_NAMES if release_family and not cancelled else _lanes_for_event(first),
		"status": &"cancelled" if cancelled else &"committed",
	})


func _schedule_runner() -> void:
	if _runner_scheduled:
		return
	_runner_scheduled = true
	call_deferred("_run_next_cue", _generation)


func _run_next_cue(scheduled_generation: int) -> void:
	_runner_scheduled = false
	if scheduled_generation != _generation or not _active_cue.is_empty():
		return
	var cue: Dictionary = {}
	var queue_depth_at_start := _major_queue.size() + _light_queue.size()
	if not _major_queue.is_empty():
		cue = _major_queue.pop_front()
	elif not _light_queue.is_empty():
		cue = _light_queue.pop_front()
	if cue.is_empty():
		return
	cue["queue_depth_at_start"] = queue_depth_at_start
	_play_cue(cue, scheduled_generation)


func _play_cue(cue: Dictionary, scheduled_generation: int) -> void:
	if scheduled_generation != _generation:
		return
	_active_cue = cue.duplicate(true)
	_lock_active_pacing(StringName(cue.get("tier", &"micro")), int(cue.get("queue_depth_at_start", 1)))
	_acquire_lanes(StringName(cue.get("cue_id", &"")), cue.get("lanes", []))
	var tier := StringName(cue.get("tier", &"micro"))
	if tier in [&"minor", &"major"]:
		_set_busy(true, StringName(cue.get("action_family", &"presentation")))
	cue_started.emit(_active_cue.duplicate(true))
	if StringName(cue.get("action_family", &"")) == &"od_release":
		_prepare_od_release_cue()
		_play_od_release_cue(scheduled_generation)
		return
	var phases: Array[StringName] = PHASE_ORDER.duplicate()
	if StringName(cue.get("status", &"committed")) in [&"cancelled", &"rejected", &"expired"]:
		phases = [&"select", &"commit"]
	for phase in phases:
		if scheduled_generation != _generation or _active_cue.is_empty():
			return
		_advance_phase(phase)
		await _wait_presentation_slice(_generic_phase_duration(tier), scheduled_generation)
		if scheduled_generation != _generation or _active_cue.is_empty():
			return
	_finish_active_cue(tier, scheduled_generation)


func _finish_active_cue(tier: StringName, scheduled_generation: int) -> void:
	if scheduled_generation != _generation or _active_cue.is_empty():
		return
	var finished := _active_cue.duplicate(true)
	_played_count += 1
	_finished_history.append(finished.duplicate(true))
	if _finished_history.size() > 64:
		_finished_history.pop_front()
	cue_finished.emit(finished)
	_release_all_lanes(StringName(finished.get("cue_id", &"")))
	_active_cue.clear()
	_active_phase = &""
	_active_duration_scale = 1.0
	_auto_fast_active = false
	if tier in [&"minor", &"major"]:
		_set_busy(false, StringName(finished.get("action_family", &"presentation")))
	if not _major_queue.is_empty() or not _light_queue.is_empty():
		_schedule_runner()


func _prepare_od_release_cue() -> void:
	var facts := _merge_event_facts(_active_cue.get("events", []))
	_active_cue["piece_type"] = StringName(facts.get("piece_type", &""))
	_active_cue["presentation_facts"] = (facts.get("presentation_facts", {}) as Dictionary).duplicate(true)
	_active_cue["result_facts"] = facts.duplicate(true)
	_active_cue["detail_trace"] = []
	_active_cue["played_audio_keys"] = []
	_active_cue["audio_group_count"] = 0


func _play_od_release_cue(scheduled_generation: int) -> void:
	var tier := StringName(_active_cue.get("tier", &"micro"))
	var status := StringName(_active_cue.get("status", &"committed"))
	_advance_phase(&"select")
	if status != &"committed":
		_append_detail(&"commit")
		_advance_phase(&"commit")
		await _wait_presentation_slice(_od_stage_duration(&"commit"), scheduled_generation)
		_finish_active_cue(tier, scheduled_generation)
		return

	_advance_phase(&"commit")
	_append_detail(&"commit")
	var vfx := _dependency_object(&"battle_vfx")
	var board_root := _dependency_object(&"board_root")
	var timeline := _od_release_timeline()
	if vfx != null and board_root != null and vfx.has_method("play_board_dim"):
		var dim_alpha := float(timeline.get("board_dim_alpha", 0.18)) * (0.55 if _reduced_motion else 1.0)
		vfx.call("play_board_dim", board_root, dim_alpha, maxf(0.04, _scaled_duration(float(timeline.get("settle_end", 1.20)))), scheduled_generation)
	await _wait_presentation_slice(_od_stage_duration(&"commit"), scheduled_generation)
	if not _cue_generation_valid(scheduled_generation): return

	_advance_phase(&"convey")
	_append_detail(&"extract")
	_play_audio_once(&"od_release_extract")
	var facts: Dictionary = _active_cue.get("result_facts", {})
	var greybox := _dependency_object(&"od_engine_greybox")
	if greybox != null and greybox.has_method("play_feedback_pulse"):
		greybox.call("play_feedback_pulse", facts.duplicate(true), &"extract", _duration_scale_for_effects())
	await _wait_presentation_slice(_od_stage_duration(&"extract"), scheduled_generation)
	if not _cue_generation_valid(scheduled_generation): return

	_append_detail(&"conduit")
	_play_audio_once(&"od_release_conduit")
	var conduit_points: Variant = _call_dependency(&"get_release_conduit_points", [facts.duplicate(true)])
	if vfx != null and board_root != null and conduit_points is Array and (conduit_points as Array).size() >= 2 and vfx.has_method("play_conduit_path"):
		var typed_points: Array[Vector2] = []
		for raw_point in conduit_points:
			if raw_point is Vector2:
				typed_points.append(raw_point)
		if typed_points.size() >= 2:
			vfx.call("play_conduit_path", board_root, typed_points, Color(0.20, 0.90, 1.0, 0.95), maxf(0.04, _scaled_duration(_od_stage_duration(&"conduit"))), scheduled_generation, _reduced_motion)
	await _wait_presentation_slice(_od_stage_duration(&"conduit"), scheduled_generation)
	if not _cue_generation_valid(scheduled_generation): return

	_append_detail(&"sigil")
	var target_position: Variant = _call_dependency(&"get_release_target_position", [facts.duplicate(true)])
	if vfx != null and board_root != null and target_position is Vector2 and vfx.has_method("play_piece_sigil"):
		vfx.call("play_piece_sigil", board_root, target_position, StringName(_active_cue.get("piece_type", &"")), Color(1.0, 0.73, 0.18, 0.95), maxf(0.08, _scaled_duration(_od_stage_duration(&"sigil"))), scheduled_generation)
	await _wait_presentation_slice(_od_stage_duration(&"sigil"), scheduled_generation)
	if not _cue_generation_valid(scheduled_generation): return

	_advance_phase(&"resolve")
	_append_detail(&"impact")
	_play_audio_once(&"od_release_impact")
	if vfx != null and board_root != null and target_position is Vector2 and vfx.has_method("play_result_badge"):
		vfx.call("play_result_badge", board_root, target_position, facts.duplicate(true), maxf(0.08, _scaled_duration(_od_stage_duration(&"impact"))), scheduled_generation)
	await _wait_presentation_slice(_od_stage_duration(&"impact"), scheduled_generation)
	if not _cue_generation_valid(scheduled_generation): return

	_append_detail(&"settle")
	_call_dependency(&"final_hud_refresh")
	await _wait_presentation_slice(_od_stage_duration(&"settle"), scheduled_generation)
	_finish_active_cue(tier, scheduled_generation)


func _append_detail(stage: StringName) -> void:
	var trace: Array = _active_cue.get("detail_trace", [])
	trace.append(stage)
	_active_cue["detail_trace"] = trace


func _merge_event_facts(raw_events: Variant) -> Dictionary:
	var merged: Dictionary = {}
	if not raw_events is Array:
		return merged
	for raw_event in raw_events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		for key in event:
			if key in ["event_id", "event_kind", "transaction_id", "sequence", "deduplicated"]:
				continue
			if key == "presentation_facts" and event[key] is Dictionary:
				var projected: Dictionary = merged.get("presentation_facts", {})
				projected.merge((event[key] as Dictionary).duplicate(true), true)
				merged["presentation_facts"] = projected
			else:
				merged[key] = event[key]
	return merged


func _play_audio_once(cue_key: StringName) -> void:
	if cue_key == &"" or _active_cue.is_empty():
		return
	var played: Array = _active_cue.get("played_audio_keys", [])
	if cue_key in played:
		return
	played.append(cue_key)
	_active_cue["played_audio_keys"] = played
	_active_cue["audio_group_count"] = played.size()
	var audio := _dependency_object(&"get_audio_manager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", str(cue_key))
		return
	_call_dependency(&"play_audio_cue", [cue_key, _active_cue.get("result_facts", {}).duplicate(true)])


func _play_monster_audio_once(action_kind: StringName, facts: Dictionary) -> void:
	match action_kind:
		&"summon": _play_audio_once(&"monster_land")
		&"attack":
			_play_audio_once(&"monster_attack")
			if bool(facts.get("ok", false)):
				_play_audio_once(&"shield_block" if int(facts.get("shield_absorbed", 0)) > 0 else &"monster_hit")
		&"skill": _play_audio_once(&"spell_cast")


func _play_generic_audio_once(action_kind: StringName, facts: Dictionary) -> void:
	match action_kind:
		&"building", &"piece_building": _play_audio_once(&"building_land")
		&"counter":
			if bool(facts.get("triggered", false)):
				_play_audio_once(&"counter_set")


func _od_release_timeline() -> Dictionary:
	if _profile != null and _profile.has_method("get_od_release_timeline"):
		return _profile.call("get_od_release_timeline")
	return {"commit_end": 0.10, "extract_end": 0.38, "conduit_end": 0.62, "sigil_end": 0.85, "impact_end": 1.05, "settle_end": 1.20, "board_dim_alpha": 0.18}


func _od_stage_duration(stage: StringName) -> float:
	var timeline := _od_release_timeline()
	var previous := 0.0
	var key := "commit_end"
	match stage:
		&"commit": key = "commit_end"
		&"extract": previous = float(timeline.get("commit_end", 0.10)); key = "extract_end"
		&"conduit": previous = float(timeline.get("extract_end", 0.38)); key = "conduit_end"
		&"sigil": previous = float(timeline.get("conduit_end", 0.62)); key = "sigil_end"
		&"impact": previous = float(timeline.get("sigil_end", 0.85)); key = "impact_end"
		&"settle": previous = float(timeline.get("impact_end", 1.05)); key = "settle_end"
	return maxf(0.0, float(timeline.get(key, previous)) - previous)


func _generic_phase_duration(tier: StringName) -> float:
	var total := 0.0
	if _profile != null and _profile.has_method("get_tier_duration"):
		total = float(_profile.call("get_tier_duration", tier))
	return total / float(maxi(1, PHASE_ORDER.size()))


func _duration_scale_for_effects() -> float:
	var scale := float(_dependencies.get("timeline_scale", 0.0))
	var pacing := _active_duration_scale if not _active_cue.is_empty() else _accessibility_duration_scale()
	scale *= pacing
	return maxf(0.05, scale if scale > 0.0 else 0.20)


func _lock_active_pacing(tier: StringName, queue_depth: int) -> void:
	var threshold := 4
	if _profile != null and _profile.has_method("get_auto_fast_queue_threshold"):
		threshold = maxi(2, int(_profile.call("get_auto_fast_queue_threshold")))
	_auto_fast_active = tier in [&"micro", &"minor"] and queue_depth >= threshold
	var scale := _accessibility_duration_scale()
	if _auto_fast_active:
		var auto_multiplier := 0.55
		if _profile != null and _profile.has_method("get_auto_fast_multiplier"):
			auto_multiplier = float(_profile.call("get_auto_fast_multiplier"))
		scale *= auto_multiplier
	_active_duration_scale = clampf(scale, 0.20, 1.0)
	if not _active_cue.is_empty():
		_active_cue["auto_fast_active"] = _auto_fast_active
		_active_cue["active_duration_scale"] = _active_duration_scale
		_active_cue["reduced_motion"] = _reduced_motion
		_active_cue["fast_mode"] = _fast_mode


func _accessibility_duration_scale() -> float:
	var scale := 1.0
	if _fast_mode:
		var fast_multiplier := 0.65
		if _profile != null and _profile.has_method("get_fast_mode_multiplier"):
			fast_multiplier = float(_profile.call("get_fast_mode_multiplier"))
		scale *= fast_multiplier
	if _reduced_motion:
		var reduced_multiplier := 0.50
		if _profile != null and _profile.has_method("get_reduced_motion_duration_multiplier"):
			reduced_multiplier = float(_profile.call("get_reduced_motion_duration_multiplier"))
		scale *= reduced_multiplier
	return clampf(scale, 0.20, 1.0)


func _scaled_duration(duration: float) -> float:
	var scale := float(_dependencies.get("timeline_scale", 0.0))
	var pacing := _active_duration_scale if not _active_cue.is_empty() else _accessibility_duration_scale()
	scale *= pacing
	return duration * scale


func _wait_presentation_slice(duration: float, scheduled_generation: int) -> void:
	var scaled := _scaled_duration(duration)
	if scaled <= 0.0 or scheduled_generation != _generation:
		return
	await get_tree().create_timer(scaled).timeout


func _cue_generation_valid(scheduled_generation: int) -> bool:
	return scheduled_generation == _generation and not _active_cue.is_empty()


func _dependency_object(key: StringName) -> Object:
	var dependency: Variant = _dependencies.get(key, null)
	if dependency is Callable and (dependency as Callable).is_valid():
		dependency = (dependency as Callable).call()
	return dependency as Object


func _advance_phase(phase: StringName) -> void:
	_active_phase = phase
	var trace: Array = _active_cue.get("phase_trace", [])
	trace.append(phase)
	_active_cue["phase_trace"] = trace
	cue_phase_changed.emit(StringName(_active_cue.get("cue_id", &"")), phase)


func _acquire_lanes(cue_id: StringName, requested: Variant) -> void:
	for lane in _sanitize_lanes(requested):
		_lane_owner[lane] = cue_id


func _release_all_lanes(cue_id: StringName) -> void:
	for lane in LANE_NAMES:
		if cue_id == &"" or StringName(_lane_owner.get(lane, &"")) == cue_id:
			_lane_owner[lane] = &""


func _set_busy(value: bool, reason: StringName) -> void:
	if _busy == value:
		return
	_busy = value
	presentation_busy_changed.emit(_busy, reason)


func _safe_tier(requested: StringName, has_transaction: bool) -> StringName:
	if requested == &"major" and not has_transaction:
		return &"micro"
	return requested if requested in [&"micro", &"minor", &"major"] else &"micro"


func _sanitize_lanes(raw: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not raw is Array:
		return result
	for value in raw:
		var lane := StringName(value)
		if lane in LANE_NAMES and not lane in result:
			result.append(lane)
	return result


func _family_for_event(event: Dictionary) -> StringName:
	var kind := StringName(event.get("event_kind", &""))
	if kind in RELEASE_EVENT_KINDS:
		return &"od_release"
	if kind in [&"heat_committed", &"heat_cooled", &"zone_changed", &"layer_advanced"]:
		return &"od_feedback"
	return kind if kind != &"" else &"generic"


func _lanes_for_event(event: Dictionary) -> Array[StringName]:
	var kind := StringName(event.get("event_kind", &""))
	if kind in RELEASE_EVENT_KINDS:
		return LANE_NAMES.duplicate()
	return [&"engine_lane", &"audio_lane"]


func _call_dependency(key: StringName, args: Array = []) -> Variant:
	var dependency: Variant = _dependencies.get(key, null)
	if dependency is Callable and (dependency as Callable).is_valid():
		return (dependency as Callable).callv(args)
	return null
