extends RefCounted
## Context-owned, disabled by default. Terrain and foundation remain existing owners.
var enabled := false
var pending: Dictionary = {}

func blank(reason: StringName) -> Dictionary:
	return {"ok": false, "active": false, "status": &"none", "reason_code": reason}

func current_target(b: Variant, target: Dictionary) -> Dictionary:
	var cell: Vector2i = target.cell
	var structure: Dictionary = b.get_structure_at_cell(cell)
	if structure.is_empty() or structure.get("structure_id") != target.structure_id or structure.owner_side != &"player" or int(structure.integrity_current) <= 0:
		return blank(&"terrain_threat_identity_lost")
	var state: Dictionary = b.get_cell_state(cell)
	if int(state.height) <= 0: return blank(&"terrain_threat_height_zero")
	var changes: Array[Dictionary] = [{"cell": cell, "expected_height": state.height, "expected_revision": state.revision,
		"target_height": int(state.height) - 1, "target_surface": state.surface}]
	var check: Dictionary = b.get_cell_state_change_status(changes, {"turn_side": &"boss"})
	if not check.get("ok", false): return blank(check.get("reason_code", &"terrain_threat_invalid"))
	return {"ok": true, "reason_code": &"ok", "cell": cell, "structure_id": structure.structure_id, "changes": changes,
		"height_before": state.height, "height_after": int(state.height) - 1,
		"will_undermine": int(state.height) - 1 < int(structure.minimum_foundation_height)}

func query(b: Variant) -> Dictionary:
	if not enabled: return blank(&"terrain_threat_disabled")
	if pending.get("status") in [&"pending", &"resolving"] or b.get_boss_siege_intent_status().get("active", false):
		return blank(&"terrain_threat_already_pending")
	var candidates: Array[Dictionary] = []
	for cell: Vector2i in b.context.get_tactical_cell_states():
		var structure: Dictionary = b.get_structure_at_cell(cell)
		if structure.is_empty(): continue
		var target := current_target(b, {"cell": cell, "structure_id": structure.structure_id})
		if target.ok: candidates.append(target)
	candidates.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
		if a.structure_id != c.structure_id: return String(a.structure_id) < String(c.structure_id)
		return a.cell.y < c.cell.y if a.cell.y != c.cell.y else a.cell.x < c.cell.x)
	return blank(&"terrain_threat_no_target") if candidates.is_empty() else candidates[0].duplicate(true)

func register_intent(b: Variant) -> Dictionary:
	var target := query(b)
	if not target.ok: return target
	pending = target.duplicate(true)
	pending.merge({"status": &"pending", "active": true, "announced_turn": b.context.turn_count,
		"player_window_turn": -1, "intent_id": StringName("terrain:%d:%s" % [b.context.turn_count, target.structure_id])})
	return status(b)

func status(b: Variant) -> Dictionary:
	if pending.is_empty(): return blank(&"terrain_threat_no_pending")
	var result := pending.duplicate(true)
	result.active = result.status in [&"pending", &"resolving"]
	if result.status == &"pending":
		var preview := current_target(b, result)
		result.merge(preview, true)
		result.active = true # Invalid target is cancelled only at an owned boundary.
		result.status = &"pending"
	return result

func player_begin(b: Variant) -> void:
	if pending.get("status") == &"pending" and int(pending.player_window_turn) < 0 and b.context.turn_count > int(pending.announced_turn):
		pending.player_window_turn = b.context.turn_count

func resolve(b: Variant) -> Dictionary:
	if pending.get("status") != &"pending": return blank(&"terrain_threat_no_pending")
	if int(pending.player_window_turn) < 0 or b.context.turn_count != int(pending.player_window_turn) or b.get_command_economy_snapshot("player").get("turn_open", false):
		return blank(&"terrain_threat_window_incomplete")
	if not enabled: return clear(&"terrain_threat_disabled")
	var target := current_target(b, pending)
	if not target.ok: return clear(target.reason_code)
	pending.status = &"resolving"
	var changes: Array[Dictionary] = []
	changes.assign(target.changes)
	var result: Dictionary = b.commit_cell_state_changes(changes, &"boss_b18", {"turn_side": &"boss"})
	pending.status = &"resolved" if result.get("ok", false) else &"cancelled"
	pending.active = false
	pending.ok = result.get("ok", false)
	pending.reason_code = result.get("reason_code", &"ok")
	pending.height_before = target.height_before
	pending.height_after = target.height_after
	pending.will_undermine = target.will_undermine
	return status(b)

func clear(reason: StringName) -> Dictionary:
	if pending.get("status") in [&"pending", &"resolving"]:
		pending.status = &"cancelled"
		pending.active = false
		pending.ok = false
		pending.reason_code = reason
	return blank(reason)
