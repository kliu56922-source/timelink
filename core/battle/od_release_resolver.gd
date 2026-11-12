extends RefCounted
## Pure Phase 27J OD-release plan builder. It never spends or mutates state.

func build_source_plan(battle: Variant, source: Variant, rules: RefCounted) -> Dictionary:
	var plan := _blank()
	if battle == null or source == null or rules == null:
		plan.reason_code = &"source_missing"
		return plan
	var state: Variant = battle._state_for_card(source)
	if state == null or state.is_dead():
		plan.reason_code = &"source_dead"
		return plan
	if state.owner_side != &"player":
		plan.reason_code = &"wrong_side"
		return plan
	if state.summoned_this_turn:
		plan.reason_code = &"summoning_sickness"
		return plan
	var piece_type: StringName = StringName(str(source.piece_type))
	var release: Dictionary = rules.get_piece_release(piece_type)
	if release.is_empty():
		plan.reason_code = &"piece_release_missing"
		return plan
	plan.piece_type = piece_type
	plan.resolver_id = StringName(str(release.get("resolver_id", "")))
	plan.action_kind = StringName(str(release.get("action_kind", "")))
	plan.command_id = StringName(str(release.get("command_id", "")))
	plan.command_cost = int(release.get("command_cost", 0))
	plan.od_cost = rules.get_release_heat_cost()
	plan.converted_heat = rules.get_converted_heat()
	plan.chain_event = StringName(str(release.get("chain_event", "")))
	plan.source = source
	plan.source_cell = battle.get_unit_cell(source)

	match piece_type:
		&"pawn", &"knight":
			# Both execute through a landing cell; knight disruption happens after landing.
			plan.legal_cells = battle.get_legal_move_cells(source)
		&"bishop":
			var dirs: Array[Vector2i] = battle.get_tactical_unit_pattern_snapshot().get_raycast_directions(&"piece_bishop")
			var rays: Dictionary = battle.scan_piece_rays(plan.source_cell, dirs, &"player", &"enemy_unit")
			plan.route_cells = rays.get("ordered_cells", [])
			plan.legal_targets = rays.get("legal_targets", [])
		&"rook":
			var dirs: Array[Vector2i] = battle.get_tactical_unit_pattern_snapshot().get_raycast_directions(&"piece_rook")
			var rays: Dictionary = battle.scan_piece_rays(plan.source_cell, dirs, &"player", &"friendly_unit")
			plan.route_cells = rays.get("ordered_cells", [])
			plan.legal_targets = rays.get("legal_targets", [])
	if (plan.legal_cells as Array).is_empty() and (plan.legal_targets as Array).is_empty():
		plan.reason_code = &"no_legal_target"
		return plan
	plan.ok = true
	plan.reason_code = &"ok"
	return plan

func validate_target(plan: Dictionary, target: Variant) -> Dictionary:
	var result: Dictionary = plan.duplicate(true)
	result.ok = false
	if not bool(plan.get("ok", false)):
		return result
	if target is Vector2i and (plan.get("legal_cells", []) as Array).has(target):
		result.ok = true
		result.reason_code = &"ok"
		result.target = target
		result.route_cells = [plan.get("source_cell", Vector2i(-1, -1)), target]
		return result
	if target != null and (plan.get("legal_targets", []) as Array).has(target):
		result.ok = true
		result.reason_code = &"ok"
		result.target = target
		return result
	result.reason_code = &"stale_target"
	return result

func _blank() -> Dictionary:
	return {
		"ok": false,
		"reason_code": &"source_missing",
		"resolver_id": &"",
		"action_kind": &"",
		"command_id": &"",
		"command_cost": 0,
		"od_cost": 0,
		"converted_heat": 0,
		"chain_event": &"",
		"piece_type": &"",
		"source": null,
		"target": null,
		"source_cell": Vector2i(-1, -1),
		"route_cells": [],
		"legal_cells": [],
		"legal_targets": [],
		"effect_payload": {},
	}
