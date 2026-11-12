extends RefCounted
class_name TacticalStructureBoardState

## Elevated Grid Phase C — authoritative structure board.
## One structure core per cell, one module per canonical shared edge, monotonic revisions.
## No Charge, OD, Depth, card cost or unit occupancy. Snapshots are deep copies.
## Only BattleSystem calls commit_prevalidated() in production; focused state smokes
## may verify atomic invariants directly.

signal transaction_committed(fact: Dictionary)

const StructureStateClass := preload("res://core/battle/tactical_structure_state.gd")
const ModuleStateClass := preload("res://core/battle/tactical_structure_module_state.gd")
const GarrisonStateClass := preload("res://core/battle/tactical_garrison_state.gd")

const EDGE_NORTH: StringName = &"north"
const EDGE_EAST: StringName = &"east"
const EDGE_SOUTH: StringName = &"south"
const EDGE_WEST: StringName = &"west"
const VALID_EDGES: Array[StringName] = [EDGE_NORTH, EDGE_EAST, EDGE_SOUTH, EDGE_WEST]

const REASON_OK: StringName = &"ok"
const REASON_BOARD_NOT_CONFIGURED: StringName = &"board_not_configured"
const REASON_STRUCTURE_MISSING: StringName = &"structure_missing"
const REASON_ORPHAN_MODULE: StringName = &"orphan_module"
const REASON_CELL_OUT_OF_BOUNDS: StringName = &"structure_cell_out_of_bounds"
const REASON_DUPLICATE_CORE_CELL: StringName = &"duplicate_core_cell"
const REASON_DUPLICATE_SOURCE_RUNTIME_ID: StringName = &"duplicate_source_runtime_id"
const REASON_MODULE_INVALID: StringName = &"module_invalid"
const REASON_MODULE_EDGE_INVALID: StringName = &"module_edge_invalid"
const REASON_DUPLICATE_CANONICAL_EDGE: StringName = &"duplicate_canonical_edge"
const REASON_STRUCTURE_REPLACEMENT_INVALID: StringName = &"structure_replacement_invalid"
const REASON_STRUCTURE_TARGET_STALE: StringName = &"structure_target_stale"
const REASON_STRUCTURE_TARGET_MISSING: StringName = &"structure_target_missing"
const REASON_STRUCTURE_DAMAGE_INVALID: StringName = &"structure_damage_invalid"
const REASON_STRUCTURE_TARGET_REQUIRED: StringName = &"structure_target_required"
const REASON_STRUCTURE_MODULE_DESTROYED: StringName = &"structure_module_destroyed"
const REASON_STRUCTURE_CORE_MISSING: StringName = &"structure_core_missing"
const REASON_GARRISON_PLAN_INVALID: StringName = &"garrison_plan_invalid"
const REASON_GARRISON_STRUCTURE_MISSING: StringName = &"garrison_structure_missing"
const REASON_GARRISON_SLOT_MISSING: StringName = &"garrison_slot_missing"
const REASON_GARRISON_SUPPORT_MISSING: StringName = &"garrison_support_missing"
const REASON_GARRISON_SUPPORT_DESTROYED: StringName = &"garrison_support_destroyed"
const REASON_GARRISON_OWNER_MISMATCH: StringName = &"garrison_owner_mismatch"
const REASON_GARRISON_PARENT_CELL_MISMATCH: StringName = &"garrison_parent_cell_mismatch"
const REASON_GARRISON_UNIT_INVALID: StringName = &"garrison_unit_invalid"
const REASON_GARRISON_SLOT_OCCUPIED: StringName = &"garrison_slot_occupied"
const REASON_GARRISON_UNIT_ALREADY_ASSIGNED: StringName = &"garrison_unit_already_assigned"
const REASON_GARRISON_STRUCTURE_STALE: StringName = &"garrison_structure_stale"
const REASON_GARRISON_REVISION_STALE: StringName = &"garrison_revision_stale"
const REASON_GARRISON_ASSIGNMENT_STALE: StringName = &"garrison_assignment_stale"
const REASON_GARRISON_STATE_INVALID: StringName = &"garrison_state_invalid"
const REASON_FOUNDATION_RECONCILE_INVALID: StringName = &"foundation_reconcile_invalid"
const REASON_FOUNDATION_RECONCILE_STALE: StringName = &"foundation_reconcile_stale"
const REASON_FOUNDATION_WINDOW_NOT_READY: StringName = &"foundation_window_not_ready"

const FOUNDATION_STABLE: StringName = &"stable"
const FOUNDATION_UNDERMINED: StringName = &"undermined"
const FOUNDATION_COLLAPSE_DUE: StringName = &"collapse_due"
const WINDOW_NONE: StringName = &"none"
const WINDOW_AWAITING: StringName = &"awaiting_owner_turn"
const WINDOW_ACTIVE: StringName = &"active_owner_turn"
const WINDOW_EXPIRED: StringName = &"expired"
const VALID_UNDERMINED_CAUSES: Array[StringName] = [
	&"terrain_lowered", &"replacement_result", &"load_reconcile", &"fixture_only",
]

var _cells: Array[Vector2i] = []
var _structures_by_id: Dictionary = {}
var _structure_id_by_cell: Dictionary = {}
var _module_id_by_canonical_edge: Dictionary = {}
var _structure_id_by_source_runtime_id: Dictionary = {}
var _modules_by_id: Dictionary = {}
var _revision: int = 0
var _garrison_by_slot_key: Dictionary = {}
var _garrison_slot_key_by_unit_runtime_id: Dictionary = {}
var _garrison_revision: int = 0


## 纯函数：把 (cell, edge) 归一化到物理共享格的 canonical key。
## east(cell) 与 west(cell + RIGHT) 落到同一 key；north(cell) 与 south(cell + UP) 同一 key。
## 棋盘 boundary edge 由所属 cell + 归一方向构成，稳定且唯一。
func canonical_edge_key(cell: Vector2i, edge: StringName) -> StringName:
	var base: Vector2i
	var dir: String
	if edge == EDGE_EAST:
		base = cell
		dir = "east"
	elif edge == EDGE_WEST:
		base = cell + Vector2i(-1, 0)
		dir = "east"
	elif edge == EDGE_NORTH:
		base = cell + Vector2i(0, -1)
		dir = "south"
	elif edge == EDGE_SOUTH:
		base = cell
		dir = "south"
	else:
		return StringName("")
	return StringName("%d,%d|%s" % [base.x, base.y, dir])


func configure_cells(cells: Array[Vector2i]) -> bool:
	if not _cells.is_empty():
		return false
	var unique := {}
	for cell in cells:
		if unique.has(cell):
			return false
		unique[cell] = true
	if unique.size() != 25:
		return false
	_cells = cells.duplicate()
	_garrison_by_slot_key.clear()
	_garrison_slot_key_by_unit_runtime_id.clear()
	_garrison_revision = 0
	return true


func get_revision() -> int:
	return _revision


func get_snapshot() -> Dictionary:
	var structures: Dictionary = {}
	for structure_id in _structures_by_id:
		structures[structure_id] = (_structures_by_id[structure_id] as RefCounted).snapshot()
	var modules: Dictionary = {}
	for module_id in _modules_by_id:
		modules[module_id] = (_modules_by_id[module_id] as RefCounted).snapshot()
	return {
		"revision": _revision,
		"structures": structures,
		"modules": modules,
		"cells": _cells.duplicate(),
	}


func get_structure_at_cell(cell: Vector2i) -> Dictionary:
	var structure_id: Variant = _structure_id_by_cell.get(cell, null)
	if structure_id == null:
		return {}
	return (_structures_by_id[structure_id] as RefCounted).snapshot()


func get_module_at_edge(cell: Vector2i, edge: StringName) -> Dictionary:
	var key: StringName = canonical_edge_key(cell, edge)
	var module_id: Variant = _module_id_by_canonical_edge.get(key, null)
	if module_id == null:
		return {}
	return (_modules_by_id[module_id] as RefCounted).snapshot()


func get_source_structure_id(runtime_id: int) -> StringName:
	var structure_id: Variant = _structure_id_by_source_runtime_id.get(runtime_id, null)
	if structure_id == null:
		return &""
	return structure_id


## Phase D2: copied foundation read model on the existing structure authority.
## Removed structures naturally disappear because there is no parallel foundation index.
func get_foundation_status(structure_id: StringName) -> Dictionary:
	var state: Variant = _structures_by_id.get(structure_id, null)
	if state == null:
		return {}
	return (state as RefCounted).snapshot().duplicate(true)


## Pure multi-structure preview. The caller supplies observations from the terrain
## authority; this board stores only the last observed height for diagnostics.
func get_foundation_reconcile_status(plan: Dictionary) -> Dictionary:
	if _cells.is_empty():
		return _invalid(REASON_BOARD_NOT_CONFIGURED)
	if int(plan.get("expected_structure_revision", -1)) != _revision:
		return _invalid(REASON_FOUNDATION_RECONCILE_STALE)
	var changes_value: Variant = plan.get("changes", null)
	if not changes_value is Array:
		return _invalid(REASON_FOUNDATION_RECONCILE_INVALID)
	var transaction_id := StringName(str(plan.get("transaction_id", &"")))
	var cause := StringName(str(plan.get("cause", &"terrain_lowered")))
	if cause not in VALID_UNDERMINED_CAUSES:
		return _invalid(REASON_FOUNDATION_RECONCILE_INVALID)
	var seen: Dictionary = {}
	var transitions: Array[Dictionary] = []
	for index in range((changes_value as Array).size()):
		var change_value: Variant = (changes_value as Array)[index]
		if not change_value is Dictionary:
			return _invalid(REASON_FOUNDATION_RECONCILE_INVALID, index)
		var change: Dictionary = change_value
		var structure_id := StringName(str(change.get("structure_id", &"")))
		if structure_id == &"" or seen.has(structure_id):
			return _invalid(REASON_FOUNDATION_RECONCILE_INVALID, index)
		seen[structure_id] = true
		if typeof(change.get("observed_height", null)) != TYPE_INT:
			return _invalid(REASON_FOUNDATION_RECONCILE_INVALID, index)
		var structure_state: Variant = _structures_by_id.get(structure_id, null)
		if structure_state == null:
			return _invalid(REASON_STRUCTURE_TARGET_MISSING, index)
		var before: Dictionary = (structure_state as RefCounted).snapshot()
		var observed_height: int = int(change.get("observed_height", 0))
		var after: Dictionary = _foundation_after_reconcile(before, observed_height, cause, transaction_id)
		if after.is_empty():
			return _invalid(REASON_FOUNDATION_RECONCILE_INVALID, index)
		if before != after:
			after["revision"] = _revision + 1
			transitions.append(_foundation_transition(before, after))
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"transaction_kind": &"foundation_reconcile",
		"transaction_id": transaction_id,
		"cause": cause,
		"expected_structure_revision": _revision,
		"structure_revision": _revision,
		"transitions": transitions.duplicate(true),
		"foundation_before": _foundation_slices_from_transitions(transitions, "foundation_before"),
		"foundation_after": _foundation_slices_from_transitions(transitions, "foundation_after"),
	}


func commit_foundation_reconcile(plan: Dictionary, options: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = get_foundation_reconcile_status(plan)
	if not bool(preview.get("ok", false)):
		return preview
	return _commit_foundation_transitions(preview, options)


## Event is a copied plan with event_kind=turn_begin|turn_end, turn_serial and
## expected_structure_revision. Awaiting windows activate only on the next begin;
## end events expire active windows only, so a same-turn undermining never collapses.
func get_owner_turn_window_status(owner_side: StringName, event: Variant) -> Dictionary:
	if _cells.is_empty():
		return _invalid(REASON_BOARD_NOT_CONFIGURED)
	if owner_side != &"player" and owner_side != &"boss":
		return _invalid(REASON_FOUNDATION_WINDOW_NOT_READY)
	if not event is Dictionary:
		return _invalid(REASON_FOUNDATION_WINDOW_NOT_READY)
	var event_plan: Dictionary = event
	if int(event_plan.get("expected_structure_revision", -1)) != _revision:
		return _invalid(REASON_FOUNDATION_RECONCILE_STALE)
	var event_kind := StringName(str(event_plan.get("event_kind", &"")))
	if event_kind != &"turn_begin" and event_kind != &"turn_end":
		return _invalid(REASON_FOUNDATION_WINDOW_NOT_READY)
	if typeof(event_plan.get("turn_serial", null)) != TYPE_INT or int(event_plan.get("turn_serial", 0)) < 0:
		return _invalid(REASON_FOUNDATION_WINDOW_NOT_READY)
	var turn_serial: int = int(event_plan.get("turn_serial", 0))
	var transitions: Array[Dictionary] = []
	var structure_ids: Array = _structures_by_id.keys()
	structure_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for structure_id_value: Variant in structure_ids:
		var structure_id := StringName(str(structure_id_value))
		var before: Dictionary = (_structures_by_id[structure_id] as RefCounted).snapshot()
		if StringName(str(before.get("owner_side", &""))) != owner_side:
			continue
		var after: Dictionary = before.duplicate(true)
		var phase := StringName(str(before.get("recovery_window_phase", WINDOW_NONE)))
		if event_kind == &"turn_begin" and phase == WINDOW_AWAITING:
			after["recovery_window_phase"] = WINDOW_ACTIVE
			after["recovery_owner_turns_remaining"] = 1
			after["window_started_turn_serial"] = turn_serial
		elif event_kind == &"turn_end" and phase == WINDOW_ACTIVE:
			after["foundation_state"] = FOUNDATION_COLLAPSE_DUE
			after["recovery_window_phase"] = WINDOW_EXPIRED
			after["recovery_owner_turns_remaining"] = 0
		else:
			continue
		after["revision"] = _revision + 1
		transitions.append(_foundation_transition(before, after))
	var collapse_ids: Array[StringName] = []
	for transition: Dictionary in transitions:
		if StringName(str((transition.get("after", {}) as Dictionary).get("foundation_state", &""))) == FOUNDATION_COLLAPSE_DUE:
			collapse_ids.append(StringName(str(transition.get("structure_id", &""))))
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"transaction_kind": &"foundation_owner_turn_window",
		"owner_side": owner_side,
		"turn_side": owner_side,
		"event_kind": event_kind,
		"turn_serial": turn_serial,
		"expected_structure_revision": _revision,
		"structure_revision": _revision,
		"recovery_window_phase": (WINDOW_ACTIVE if event_kind == &"turn_begin" else WINDOW_EXPIRED) if not transitions.is_empty() else WINDOW_NONE,
		"transitions": transitions.duplicate(true),
		"collapse_structure_ids": collapse_ids.duplicate(),
		"foundation_before": _foundation_slices_from_transitions(transitions, "foundation_before"),
		"foundation_after": _foundation_slices_from_transitions(transitions, "foundation_after"),
	}


func commit_owner_turn_window(event_plan: Dictionary) -> Dictionary:
	var owner_side := StringName(str(event_plan.get("owner_side", event_plan.get("turn_side", &""))))
	var preview: Dictionary = get_owner_turn_window_status(owner_side, event_plan)
	if not bool(preview.get("ok", false)):
		return preview
	return _commit_foundation_transitions(preview)


func _foundation_after_reconcile(
	before: Dictionary,
	observed_height: int,
	cause: StringName,
	transaction_id: StringName,
) -> Dictionary:
	var after: Dictionary = before.duplicate(true)
	var current_state := StringName(str(before.get("foundation_state", FOUNDATION_STABLE)))
	if current_state not in [FOUNDATION_STABLE, FOUNDATION_UNDERMINED, FOUNDATION_COLLAPSE_DUE]:
		return {}
	# collapse_due is an already committed terminal fact. BattleSystem consumes it
	# through core cleanup; a late terrain observation cannot resurrect the core.
	if current_state == FOUNDATION_COLLAPSE_DUE:
		return after
	after["foundation_observed_height"] = observed_height
	if observed_height >= int(before.get("minimum_foundation_height", 1)):
		after["foundation_state"] = FOUNDATION_STABLE
		after["recovery_window_phase"] = WINDOW_NONE
		after["recovery_owner_turns_remaining"] = 0
		after["undermined_cause"] = &""
		after["undermined_transaction_id"] = &""
		after["window_started_turn_serial"] = 0
		return after
	if current_state == FOUNDATION_STABLE:
		if transaction_id == &"":
			return {}
		after["foundation_state"] = FOUNDATION_UNDERMINED
		after["recovery_window_phase"] = WINDOW_AWAITING
		after["recovery_owner_turns_remaining"] = 1
		after["undermined_cause"] = cause
		after["undermined_transaction_id"] = transaction_id
		after["window_started_turn_serial"] = 0
	return after


func _foundation_transition(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"structure_id": before.get("structure_id", &""),
		"owner_side": before.get("owner_side", &""),
		"cell": before.get("cell", Vector2i(-1, -1)),
		"before": before.duplicate(true),
		"after": after.duplicate(true),
		"foundation_before": _foundation_slice(before),
		"foundation_after": _foundation_slice(after),
	}


func _foundation_slice(snapshot: Dictionary) -> Dictionary:
	return {
		"foundation_state": snapshot.get("foundation_state", FOUNDATION_STABLE),
		"minimum_foundation_height": int(snapshot.get("minimum_foundation_height", 1)),
		"foundation_observed_height": int(snapshot.get("foundation_observed_height", 1)),
		"recovery_window_phase": snapshot.get("recovery_window_phase", WINDOW_NONE),
		"recovery_owner_turns_remaining": int(snapshot.get("recovery_owner_turns_remaining", 0)),
		"undermined_cause": snapshot.get("undermined_cause", &""),
		"undermined_transaction_id": snapshot.get("undermined_transaction_id", &""),
		"window_started_turn_serial": int(snapshot.get("window_started_turn_serial", 0)),
	}


func _foundation_slices_from_transitions(transitions: Array, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for transition_value: Variant in transitions:
		if transition_value is Dictionary:
			var value: Variant = (transition_value as Dictionary).get(key, {})
			if value is Dictionary:
				result.append((value as Dictionary).duplicate(true))
	return result


## Reverse the latest unpublished foundation receipt without touching modules,
## garrison assignments, identities, or any other authority.
func rollback_foundation_reconcile(fact: Dictionary) -> void:
	if not bool(fact.get("ok", false)) or not bool(fact.get("changed", false)):
		return
	if int(fact.get("revision", -1)) != _revision or int(fact.get("previous_revision", -2)) + 1 != _revision:
		return
	var transitions: Array = fact.get("transitions", [])
	if transitions.is_empty():
		return
	var replacements: Dictionary = _structures_by_id.duplicate()
	var seen: Dictionary = {}
	for value: Variant in transitions:
		if not value is Dictionary:
			return
		var transition: Dictionary = value
		var structure_id := StringName(str(transition.get("structure_id", &"")))
		var current: Variant = _structures_by_id.get(structure_id)
		var before: Dictionary = transition.get("before", {})
		if current == null or seen.has(structure_id) or current.snapshot() != transition.get("after", {}):
			return
		if before.get("structure_id") != structure_id:
			return
		seen[structure_id] = true
		replacements[structure_id] = current.copy_with_foundation(
			StringName(before.foundation_state), int(before.foundation_observed_height),
			StringName(before.recovery_window_phase), int(before.recovery_owner_turns_remaining),
			StringName(before.undermined_cause), StringName(before.undermined_transaction_id),
			int(before.window_started_turn_serial), int(before.revision))
	_structures_by_id = replacements
	_revision = int(fact.previous_revision)


func publish_foundation_fact(fact: Dictionary) -> void:
	if bool(fact.get("ok", false)) and bool(fact.get("changed", false)):
		transaction_committed.emit(fact.duplicate(true))


func _commit_foundation_transitions(preview: Dictionary, options: Dictionary = {}) -> Dictionary:
	var transitions: Array = preview.get("transitions", [])
	var result: Dictionary = preview.duplicate(true)
	result["previous_revision"] = _revision
	result["revision"] = _revision
	result["structure_revision"] = _revision
	result["changed"] = not transitions.is_empty()
	result["foundation_before"] = []
	result["foundation_after"] = []
	for transition_value: Variant in transitions:
		if transition_value is Dictionary:
			(result["foundation_before"] as Array).append((transition_value as Dictionary).get("foundation_before", {}).duplicate(true))
			(result["foundation_after"] as Array).append((transition_value as Dictionary).get("foundation_after", {}).duplicate(true))
	if transitions.is_empty():
		return result.duplicate(true)

	var next_structures: Dictionary = _structures_by_id.duplicate()
	var next_revision: int = _revision + 1
	for transition_value: Variant in transitions:
		if not transition_value is Dictionary:
			return _invalid(REASON_FOUNDATION_RECONCILE_INVALID)
		var transition: Dictionary = transition_value
		var structure_id := StringName(str(transition.get("structure_id", &"")))
		var current_state: Variant = _structures_by_id.get(structure_id, null)
		if current_state == null or (current_state as RefCounted).snapshot() != transition.get("before", {}):
			return _invalid(REASON_FOUNDATION_RECONCILE_STALE)
		var after: Dictionary = transition.get("after", {})
		var updated: RefCounted = (current_state as RefCounted).copy_with_foundation(
			StringName(str(after.get("foundation_state", FOUNDATION_STABLE))),
			int(after.get("foundation_observed_height", 0)),
			StringName(str(after.get("recovery_window_phase", WINDOW_NONE))),
			int(after.get("recovery_owner_turns_remaining", 0)),
			StringName(str(after.get("undermined_cause", &""))),
			StringName(str(after.get("undermined_transaction_id", &""))),
			int(after.get("window_started_turn_serial", 0)),
			next_revision,
		)
		next_structures[structure_id] = updated
	_structures_by_id = next_structures
	_revision = next_revision
	result["revision"] = _revision
	result["structure_revision"] = _revision
	if not bool(options.get("defer_signal", false)):
		transaction_committed.emit(result.duplicate(true))
	return result.duplicate(true)


## Phase D1 Task 2: copied read model for the unique garrison assignment authority.
## The slot dictionary is keyed by "<structure_id>|<slot_id>"; the reverse index
## guarantees that a unit runtime id cannot occupy a second slot.
func get_garrison_snapshot() -> Dictionary:
	var assignments: Dictionary = {}
	for slot_key in _garrison_by_slot_key:
		assignments[slot_key] = (_garrison_by_slot_key[slot_key] as RefCounted).snapshot()
	return {
		"revision": _garrison_revision,
		"assignments": assignments,
		"slot_key_by_unit_runtime_id": _garrison_slot_key_by_unit_runtime_id.duplicate(true),
	}


func get_garrison_for_unit(unit_runtime_id: int) -> Dictionary:
	var slot_key: Variant = _garrison_slot_key_by_unit_runtime_id.get(unit_runtime_id, null)
	if slot_key == null:
		return {}
	var assignment_state: Variant = _garrison_by_slot_key.get(slot_key, null)
	if assignment_state == null:
		return {}
	return (assignment_state as RefCounted).snapshot()


func get_garrison_for_slot(structure_id: StringName, slot_id: StringName) -> Dictionary:
	var assignment_state: Variant = _garrison_by_slot_key.get(_garrison_slot_key(structure_id, slot_id), null)
	if assignment_state == null:
		return {}
	return (assignment_state as RefCounted).snapshot()


## Pure assign preview. This revalidates the live structure, slot descriptor,
## support module, both uniqueness indexes and both authority revisions.
func get_garrison_assign_status(plan: Dictionary) -> Dictionary:
	if _cells.is_empty():
		return _invalid(REASON_BOARD_NOT_CONFIGURED)
	if int(plan.get("expected_structure_revision", -1)) != _revision:
		return _invalid(REASON_GARRISON_STRUCTURE_STALE)
	if int(plan.get("expected_garrison_revision", -1)) != _garrison_revision:
		return _invalid(REASON_GARRISON_REVISION_STALE)

	var structure_id := StringName(str(plan.get("structure_id", &"")))
	var slot_id := StringName(str(plan.get("slot_id", &"")))
	var unit_runtime_id: int = int(plan.get("unit_runtime_id", 0))
	var owner_side := StringName(str(plan.get("owner_side", &"")))
	var socket_name := StringName(str(plan.get("socket_name", &"")))
	var slot_role := StringName(str(plan.get("slot_role", &"")))
	var support_module_id := StringName(str(plan.get("support_module_id", &"")))
	var parent_cell_value: Variant = plan.get("parent_cell", null)
	if structure_id == &"" or slot_id == &"" or owner_side == &"" \
	or socket_name == &"" or slot_role == &"" or support_module_id == &"" \
	or not parent_cell_value is Vector2i:
		return _invalid(REASON_GARRISON_PLAN_INVALID)
	if unit_runtime_id <= 0:
		return _invalid(REASON_GARRISON_UNIT_INVALID)

	var structure_state: Variant = _structures_by_id.get(structure_id, null)
	if structure_state == null:
		return _invalid(REASON_GARRISON_STRUCTURE_MISSING)
	var structure: Dictionary = (structure_state as RefCounted).snapshot()
	var parent_cell: Vector2i = structure.get("cell", Vector2i(-1, -1))
	var footprint: Array = structure.get("footprint_cells", [parent_cell])
	if footprint.size() == 2: parent_cell = footprint[1]
	if parent_cell != parent_cell_value:
		return _invalid(REASON_GARRISON_PARENT_CELL_MISMATCH)
	if StringName(str(structure.get("owner_side", &""))) != owner_side:
		return _invalid(REASON_GARRISON_OWNER_MISMATCH)
	if not _structure_has_garrison_slot(structure, slot_id, socket_name, slot_role):
		return _invalid(REASON_GARRISON_SLOT_MISSING)

	var support_state: Variant = _modules_by_id.get(support_module_id, null)
	if support_state == null:
		return _invalid(REASON_GARRISON_SUPPORT_MISSING)
	var support: Dictionary = (support_state as RefCounted).snapshot()
	if StringName(str(support.get("structure_id", &""))) != structure_id:
		return _invalid(REASON_GARRISON_SUPPORT_MISSING)
	if int(support.get("integrity_current", 0)) <= 0 or StringName(str(support.get("status", &""))) == &"destroyed":
		return _invalid(REASON_GARRISON_SUPPORT_DESTROYED)

	var slot_key: StringName = _garrison_slot_key(structure_id, slot_id)
	if _garrison_by_slot_key.has(slot_key):
		return _invalid(REASON_GARRISON_SLOT_OCCUPIED)
	if _garrison_slot_key_by_unit_runtime_id.has(unit_runtime_id):
		return _invalid(REASON_GARRISON_UNIT_ALREADY_ASSIGNED)

	return {
		"ok": true,
		"reason_code": REASON_OK,
		"assignment": {
			"structure_id": structure_id,
			"slot_id": slot_id,
			"unit_runtime_id": unit_runtime_id,
			"owner_side": owner_side,
			"parent_cell": parent_cell_value,
			"socket_name": socket_name,
			"slot_role": slot_role,
			"support_module_id": support_module_id,
			"platform_height_offset": int(plan.get("platform_height_offset", 0)),
			"entered_turn": int(plan.get("entered_turn", 0)),
		},
	}


func apply_garrison_assign(plan: Dictionary) -> Dictionary:
	var status: Dictionary = get_garrison_assign_status(plan)
	if not bool(status.get("ok", false)):
		return status
	var assignment: Dictionary = status.get("assignment", {})
	var next_revision: int = _garrison_revision + 1
	var assignment_state: RefCounted = GarrisonStateClass.new(
		assignment.get("structure_id", &""),
		assignment.get("slot_id", &""),
		int(assignment.get("unit_runtime_id", 0)),
		assignment.get("owner_side", &"player"),
		assignment.get("parent_cell", Vector2i(-1, -1)),
		assignment.get("socket_name", &""),
		assignment.get("slot_role", &""),
		assignment.get("support_module_id", &""),
		int(assignment.get("platform_height_offset", 0)),
		int(assignment.get("entered_turn", 0)),
		&"active",
		next_revision,
	)
	var slot_key: StringName = _garrison_slot_key(assignment_state.structure_id, assignment_state.slot_id)
	var next_by_slot: Dictionary = _garrison_by_slot_key.duplicate()
	var next_by_unit: Dictionary = _garrison_slot_key_by_unit_runtime_id.duplicate()
	next_by_slot[slot_key] = assignment_state
	next_by_unit[assignment_state.unit_runtime_id] = slot_key
	_garrison_by_slot_key = next_by_slot
	_garrison_slot_key_by_unit_runtime_id = next_by_unit
	var previous_revision: int = _garrison_revision
	_garrison_revision = next_revision
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"transaction_kind": &"garrison_assign",
		"changed": true,
		"before": {},
		"after": assignment_state.snapshot(),
		"garrison_revision_before": previous_revision,
		"garrison_revision_after": _garrison_revision,
	}.duplicate(true)


## Pure clear preview. Absence is an idempotent success and intentionally wins
## over stale revision checks, allowing repeated cleanup after the first success.
func get_garrison_clear_status(plan: Dictionary) -> Dictionary:
	var structure_id := StringName(str(plan.get("structure_id", &"")))
	var slot_id := StringName(str(plan.get("slot_id", &"")))
	var unit_runtime_id: int = int(plan.get("unit_runtime_id", 0))
	if structure_id == &"" or slot_id == &"" or unit_runtime_id <= 0:
		return _invalid(REASON_GARRISON_PLAN_INVALID)
	var slot_key: StringName = _garrison_slot_key(structure_id, slot_id)
	var assignment_state: Variant = _garrison_by_slot_key.get(slot_key, null)
	if assignment_state == null:
		if not _garrison_slot_key_by_unit_runtime_id.has(unit_runtime_id):
			return {"ok": true, "reason_code": REASON_OK, "changed": false, "before": {}}
		return _invalid(REASON_GARRISON_ASSIGNMENT_STALE)
	var assignment: Dictionary = (assignment_state as RefCounted).snapshot()
	if int(assignment.get("unit_runtime_id", 0)) != unit_runtime_id:
		return _invalid(REASON_GARRISON_ASSIGNMENT_STALE)
	if int(plan.get("expected_garrison_revision", -1)) != _garrison_revision:
		return _invalid(REASON_GARRISON_REVISION_STALE)
	if int(plan.get("expected_assignment_revision", -1)) != int(assignment.get("assignment_revision", -2)):
		return _invalid(REASON_GARRISON_ASSIGNMENT_STALE)
	return {"ok": true, "reason_code": REASON_OK, "changed": true, "before": assignment}


func apply_garrison_clear(plan: Dictionary) -> Dictionary:
	var status: Dictionary = get_garrison_clear_status(plan)
	if not bool(status.get("ok", false)):
		return status
	if not bool(status.get("changed", false)):
		return {
			"ok": true,
			"reason_code": REASON_OK,
			"transaction_kind": &"garrison_clear",
			"changed": false,
			"before": {},
			"after": {},
			"garrison_revision_before": _garrison_revision,
			"garrison_revision_after": _garrison_revision,
		}
	var before: Dictionary = status.get("before", {})
	var slot_key: StringName = _garrison_slot_key(before.get("structure_id", &""), before.get("slot_id", &""))
	var next_by_slot: Dictionary = _garrison_by_slot_key.duplicate()
	var next_by_unit: Dictionary = _garrison_slot_key_by_unit_runtime_id.duplicate()
	next_by_slot.erase(slot_key)
	next_by_unit.erase(int(before.get("unit_runtime_id", 0)))
	_garrison_by_slot_key = next_by_slot
	_garrison_slot_key_by_unit_runtime_id = next_by_unit
	var previous_revision: int = _garrison_revision
	_garrison_revision += 1
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"transaction_kind": &"garrison_clear",
		"changed": true,
		"before": before,
		"after": {},
		"garrison_revision_before": previous_revision,
		"garrison_revision_after": _garrison_revision,
	}.duplicate(true)


## Retains slot and unit identity so BattleSystem can perform the later forced
## exit atomically. Repeating the mark after success is a no-op.
func mark_garrison_displaced(plan: Dictionary) -> Dictionary:
	var structure_id := StringName(str(plan.get("structure_id", &"")))
	var slot_id := StringName(str(plan.get("slot_id", &"")))
	var unit_runtime_id: int = int(plan.get("unit_runtime_id", 0))
	if structure_id == &"" or slot_id == &"" or unit_runtime_id <= 0:
		return _invalid(REASON_GARRISON_PLAN_INVALID)
	var slot_key: StringName = _garrison_slot_key(structure_id, slot_id)
	var assignment_state: Variant = _garrison_by_slot_key.get(slot_key, null)
	if assignment_state == null:
		return _invalid(REASON_GARRISON_ASSIGNMENT_STALE)
	var before: Dictionary = (assignment_state as RefCounted).snapshot()
	if int(before.get("unit_runtime_id", 0)) != unit_runtime_id:
		return _invalid(REASON_GARRISON_ASSIGNMENT_STALE)
	if StringName(str(before.get("state", &""))) == &"displaced_pending_exit":
		return {
			"ok": true,
			"reason_code": REASON_OK,
			"transaction_kind": &"garrison_displace",
			"changed": false,
			"before": before.duplicate(true),
			"after": before.duplicate(true),
			"garrison_revision_before": _garrison_revision,
			"garrison_revision_after": _garrison_revision,
		}
	if StringName(str(before.get("state", &""))) != &"active":
		return _invalid(REASON_GARRISON_STATE_INVALID)
	if int(plan.get("expected_garrison_revision", -1)) != _garrison_revision:
		return _invalid(REASON_GARRISON_REVISION_STALE)
	if int(plan.get("expected_assignment_revision", -1)) != int(before.get("assignment_revision", -2)):
		return _invalid(REASON_GARRISON_ASSIGNMENT_STALE)
	var previous_revision: int = _garrison_revision
	var next_revision: int = previous_revision + 1
	var displaced_state: RefCounted = (assignment_state as RefCounted).copy_with_state(&"displaced_pending_exit", next_revision)
	var next_by_slot: Dictionary = _garrison_by_slot_key.duplicate()
	next_by_slot[slot_key] = displaced_state
	_garrison_by_slot_key = next_by_slot
	_garrison_revision = next_revision
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"transaction_kind": &"garrison_displace",
		"changed": true,
		"before": before,
		"after": displaced_state.snapshot(),
		"garrison_revision_before": previous_revision,
		"garrison_revision_after": _garrison_revision,
	}.duplicate(true)


func _garrison_slot_key(structure_id: StringName, slot_id: StringName) -> StringName:
	return StringName("%s|%s" % [structure_id, slot_id])


func _structure_has_garrison_slot(structure: Dictionary, slot_id: StringName, socket_name: StringName, slot_role: StringName) -> bool:
	var definitions: Array = structure.get("reserved_garrison_slot_defs", [])
	for value: Variant in definitions:
		if not value is Dictionary:
			continue
		var definition: Dictionary = value
		if StringName(str(definition.get("slot_id", &""))) == slot_id \
		and StringName(str(definition.get("socket_name", &""))) == socket_name \
		and StringName(str(definition.get("slot_role", &""))) == slot_role:
			return true
	return false


func get_change_status(plan: Dictionary) -> Dictionary:
	if _cells.is_empty():
		return _invalid(REASON_BOARD_NOT_CONFIGURED)
	var replacement: Dictionary = _get_replacement_targets(plan)
	if not bool(replacement.get("ok", false)):
		return replacement
	var structure: Dictionary = plan.get("structure", {})
	var modules: Array = plan.get("modules", [])
	if not modules is Array:
		return _invalid(REASON_MODULE_INVALID)
	if structure.is_empty() and not modules.is_empty():
		return _invalid(REASON_ORPHAN_MODULE)
	if structure.is_empty():
		return _invalid(REASON_STRUCTURE_MISSING)

	var cell_value: Variant = structure.get("cell", null)
	if not cell_value is Vector2i or not cell_value in _cells:
		return _invalid(REASON_CELL_OUT_OF_BOUNDS)
	var cell: Vector2i = cell_value
	var staged_cell_index: Dictionary = _structure_id_by_cell.duplicate()
	var staged_source_index: Dictionary = _structure_id_by_source_runtime_id.duplicate()
	var staged_edge_index: Dictionary = _module_id_by_canonical_edge.duplicate()
	for structure_id: StringName in replacement.get("structure_ids", []):
		var existing_state: Variant = _structures_by_id.get(structure_id, null)
		if existing_state == null:
			return _invalid(REASON_STRUCTURE_TARGET_STALE)
		var existing: Dictionary = (existing_state as RefCounted).snapshot()
		for occupied in existing.get("footprint_cells", [existing.cell]):
			staged_cell_index.erase(occupied)
		staged_source_index.erase(int(existing.get("source_runtime_id", 0)))
		for module_id: StringName in existing.get("module_ids", []):
			var existing_module_state: Variant = _modules_by_id.get(module_id, null)
			if existing_module_state == null:
				return _invalid(REASON_STRUCTURE_TARGET_STALE)
			var existing_module: Dictionary = (existing_module_state as RefCounted).snapshot()
			staged_edge_index.erase(existing_module.get("canonical_edge", &""))
	var footprint: Array = structure.get("footprint_cells", [cell])
	if footprint.is_empty() or footprint[0] != cell or footprint.size() not in [1, 2, 4]:
		return _invalid(REASON_CELL_OUT_OF_BOUNDS)
	var seen := {}
	for occupied in footprint:
		if not occupied is Vector2i or not occupied in _cells or seen.has(occupied):
			return _invalid(REASON_CELL_OUT_OF_BOUNDS)
		if staged_cell_index.has(occupied): return _invalid(REASON_DUPLICATE_CORE_CELL)
		seen[occupied] = true
	var minimum: Vector2i = cell
	var maximum: Vector2i = cell
	for occupied: Vector2i in footprint:
		minimum = Vector2i(mini(minimum.x, occupied.x), mini(minimum.y, occupied.y))
		maximum = Vector2i(maxi(maximum.x, occupied.x), maxi(maximum.y, occupied.y))
	var extent: Vector2i = maximum - minimum + Vector2i.ONE
	if extent.x > 2 or extent.y > 2 or extent.x * extent.y != footprint.size():
		return _invalid(REASON_CELL_OUT_OF_BOUNDS)
	var runtime_id: int = int(structure.get("source_runtime_id", 0))
	if runtime_id != 0 and staged_source_index.has(runtime_id):
		return _invalid(REASON_DUPLICATE_SOURCE_RUNTIME_ID)

	var checked_edges := {}
	for index in range(modules.size()):
		var module: Variant = modules[index]
		if not module is Dictionary:
			return _invalid(REASON_MODULE_INVALID, index)
		var edge := StringName(str((module as Dictionary).get("edge", &"")))
		if edge not in VALID_EDGES:
			return _invalid(REASON_MODULE_EDGE_INVALID, index)
		var key: StringName = canonical_edge_key(cell, edge)
		if key == StringName("") or checked_edges.has(key) or staged_edge_index.has(key):
			return _invalid(REASON_DUPLICATE_CANONICAL_EDGE, index)
		checked_edges[key] = true
	return {"ok": true, "reason_code": REASON_OK}


func commit_prevalidated(plan: Dictionary) -> Dictionary:
	var status: Dictionary = get_change_status(plan)
	if not bool(status.get("ok", false)):
		return status
	var replacement: Dictionary = _get_replacement_targets(plan)

	var structure: Dictionary = plan["structure"]
	var cell: Vector2i = structure["cell"]
	var runtime_id: int = int(structure.get("source_runtime_id", 0))
	var structure_id := StringName("structure:card:%d" % runtime_id)
	var profile_id := StringName(str(structure.get("profile_id", &"")))
	var owner_side := StringName(str(structure.get("owner_side", &"player")))
	var source_kind := StringName(str(structure.get("source_kind", &"card")))
	var source_card_id := StringName(str(structure.get("source_card_id", &"")))
	var min_height: int = int(structure.get("minimum_foundation_height", 1))
	var integrity_max: int = int(structure.get("integrity_max", 1))
	var integrity_current: int = int(structure.get("integrity_current", integrity_max))
	var reserved_slots: int = int(structure.get("reserved_garrison_slots", 0))
	var garrison_defs: Array = structure.get("reserved_garrison_slot_defs", [])

	var next_structures: Dictionary = _structures_by_id.duplicate()
	var next_cell_index: Dictionary = _structure_id_by_cell.duplicate()
	var next_source_index: Dictionary = _structure_id_by_source_runtime_id.duplicate()
	var next_modules: Dictionary = _modules_by_id.duplicate()
	var next_edge_index: Dictionary = _module_id_by_canonical_edge.duplicate()
	var removed_structures: Array[Dictionary] = []
	var removed_modules: Array[Dictionary] = []
	for removed_structure_id: StringName in replacement.get("structure_ids", []):
		var removed_structure_state: RefCounted = next_structures[removed_structure_id]
		var removed_structure: Dictionary = removed_structure_state.snapshot()
		removed_structures.append(removed_structure)
		next_structures.erase(removed_structure_id)
		for occupied in removed_structure.get("footprint_cells", [removed_structure.cell]):
			next_cell_index.erase(occupied)
		next_source_index.erase(int(removed_structure.get("source_runtime_id", 0)))
		for removed_module_id: StringName in removed_structure.get("module_ids", []):
			var removed_module_state: RefCounted = next_modules[removed_module_id]
			var removed_module: Dictionary = removed_module_state.snapshot()
			removed_modules.append(removed_module)
			next_modules.erase(removed_module_id)
			next_edge_index.erase(removed_module.get("canonical_edge", &""))

	var module_snapshots: Array[Dictionary] = []
	var module_ids: Array[StringName] = []
	for index in range((plan.get("modules", []) as Array).size()):
		var module: Dictionary = (plan.get("modules", []) as Array)[index]
		var edge := StringName(str(module.get("edge", &"")))
		var module_kind := StringName(str(module.get("module_kind", &"wall")))
		var module_integrity_max: int = int(module.get("integrity_max", 1))
		var module_integrity_current: int = int(module.get("integrity_current", module_integrity_max))
		var module_id := StringName("%s:edge:%s" % [structure_id, edge])
		var blocks: bool = bool(module.get("blocks_hostile_path", module_kind != &"gatehouse"))
		var allows_passage: bool = bool(module.get("allows_owner_passage", module_kind == &"gatehouse"))
		var module_state: RefCounted = ModuleStateClass.new(
			module_id, structure_id, module_kind, edge,
			module_integrity_current, module_integrity_max, blocks, allows_passage,
			canonical_edge_key(cell, edge),
		)
		next_modules[module_id] = module_state
		next_edge_index[canonical_edge_key(cell, edge)] = module_id
		module_ids.append(module_id)
		module_snapshots.append(module_state.snapshot())

	var structure_state: RefCounted = StructureStateClass.new(
		structure_id, profile_id, owner_side, source_kind, runtime_id, source_card_id,
		cell, min_height, integrity_current, integrity_max, reserved_slots, garrison_defs, module_ids,
		&"stable", int(structure.get("foundation_observed_height", min_height)),
	)
	structure_state.footprint_cells.assign(structure.get("footprint_cells", [cell]))
	next_structures[structure_id] = structure_state
	for occupied in structure_state.footprint_cells:
		next_cell_index[occupied] = structure_id
	if runtime_id != 0:
		next_source_index[runtime_id] = structure_id

	_structures_by_id = next_structures
	_structure_id_by_cell = next_cell_index
	_structure_id_by_source_runtime_id = next_source_index
	_modules_by_id = next_modules
	_module_id_by_canonical_edge = next_edge_index
	_revision += 1

	var fact := {
		"ok": true,
		"reason_code": REASON_OK,
		"revision": _revision,
		"structure": structure_state.snapshot(),
		"modules": module_snapshots,
		"removed_structures": removed_structures,
		"removed_modules": removed_modules,
	}
	transaction_committed.emit(fact.duplicate(true))
	return fact.duplicate(true)


## Phase C Task 5: pure target validation and before/after damage preview.
## Terrain revision is owned by TacticalBoardState, so BattleSystem validates it
## before reaching this single structure authority.
func get_damage_status(target_ref: Dictionary, steps: int) -> Dictionary:
	if steps <= 0:
		return _invalid(REASON_STRUCTURE_DAMAGE_INVALID)
	if target_ref.is_empty():
		return _invalid(REASON_STRUCTURE_TARGET_REQUIRED)
	var cell_value: Variant = target_ref.get("cell", null)
	if not cell_value is Vector2i:
		return _invalid(REASON_STRUCTURE_TARGET_STALE)
	var cell: Vector2i = cell_value
	var target_kind := StringName(str(target_ref.get("target_kind", &"")))
	var structure_id := StringName(str(target_ref.get("structure_id", &"")))
	if structure_id == &"" or _structure_id_by_cell.get(cell, &"") != structure_id:
		return _invalid(REASON_STRUCTURE_CORE_MISSING if target_kind == &"structure_core" else REASON_STRUCTURE_TARGET_STALE)
	var structure_state: Variant = _structures_by_id.get(structure_id, null)
	if structure_state == null:
		return _invalid(REASON_STRUCTURE_CORE_MISSING if target_kind == &"structure_core" else REASON_STRUCTURE_TARGET_STALE)
	var structure: Dictionary = (structure_state as RefCounted).snapshot()
	if target_kind == &"structure_core":
		if int(target_ref.get("expected_structure_revision", -1)) != _revision:
			return _invalid(REASON_STRUCTURE_TARGET_STALE)
		if StringName(str(target_ref.get("module_id", &""))) != &"" or int(target_ref.get("expected_module_revision", -1)) != -1:
			return _invalid(REASON_STRUCTURE_TARGET_STALE)
		return _damage_preview(target_ref, structure, steps, true)
	if target_kind != &"structure_module":
		return _invalid(REASON_STRUCTURE_TARGET_STALE)
	var module_id := StringName(str(target_ref.get("module_id", &"")))
	var module_state: Variant = _modules_by_id.get(module_id, null)
	if module_state == null:
		return _invalid(REASON_STRUCTURE_TARGET_STALE)
	var module: Dictionary = (module_state as RefCounted).snapshot()
	if int(module.get("integrity_current", 0)) <= 0:
		return _invalid(REASON_STRUCTURE_MODULE_DESTROYED)
	if StringName(str(module.get("structure_id", &""))) != structure_id \
	or StringName(str(target_ref.get("edge", &""))) != StringName(str(module.get("edge", &""))) \
	or int(target_ref.get("expected_module_revision", -1)) != int(module.get("revision", -2)):
		return _invalid(REASON_STRUCTURE_TARGET_STALE)
	if int(target_ref.get("expected_structure_revision", -1)) != _revision:
		return _invalid(REASON_STRUCTURE_TARGET_STALE)
	return _damage_preview(target_ref, module, steps, false)


## Commits only prevalidated structural damage. Core cleanup and terrain ruins are
## deliberately outside this class and remain BattleSystem responsibilities.
func commit_damage(target_ref: Dictionary, steps: int, options: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = get_damage_status(target_ref, steps)
	if not bool(preview.get("ok", false)):
		return preview
	var target_kind := StringName(str((preview.get("target", {}) as Dictionary).get("target_kind", &"")))
	var target: Dictionary = preview.get("target", {})
	var structure_id := StringName(str(target.get("structure_id", &"")))
	var next_structures: Dictionary = _structures_by_id.duplicate()
	var next_modules: Dictionary = _modules_by_id.duplicate()
	var next_cell_index: Dictionary = _structure_id_by_cell.duplicate()
	var next_source_index: Dictionary = _structure_id_by_source_runtime_id.duplicate()
	var next_edge_index: Dictionary = _module_id_by_canonical_edge.duplicate()
	if target_kind == &"structure_module":
		var module_id := StringName(str(target.get("module_id", &"")))
		var module_state: RefCounted = next_modules[module_id]
		next_modules[module_id] = module_state.copy_with(int((preview.get("after", {}) as Dictionary).get("integrity_current", 0)))
	else:
		var structure_state: RefCounted = next_structures[structure_id]
		if not bool(preview.get("core_destroyed", false)):
			next_structures[structure_id] = structure_state.copy_with(int((preview.get("after", {}) as Dictionary).get("integrity_current", 0)))
		else:
			var before: Dictionary = preview.get("before", {})
			next_structures.erase(structure_id)
			for occupied in before.get("footprint_cells", [before.cell]):
				next_cell_index.erase(occupied)
			next_source_index.erase(int(before.get("source_runtime_id", 0)))
			for module_id: StringName in before.get("module_ids", []):
				var module_state: Variant = next_modules.get(module_id, null)
				if module_state != null:
					var module: Dictionary = (module_state as RefCounted).snapshot()
					next_modules.erase(module_id)
					next_edge_index.erase(module.get("canonical_edge", &""))
	_structures_by_id = next_structures
	_modules_by_id = next_modules
	_structure_id_by_cell = next_cell_index
	_structure_id_by_source_runtime_id = next_source_index
	_module_id_by_canonical_edge = next_edge_index
	_revision += 1
	var fact: Dictionary = preview.duplicate(true)
	fact["previous_revision"] = _revision - 1
	fact["revision"] = _revision
	if target_kind == &"structure_module":
		fact["after"] = (next_modules[StringName(str(target.get("module_id", &"")))] as RefCounted).snapshot()
	fact["breach_created"] = StringName(str(fact.after.get("status", &""))) == &"destroyed" and StringName(str((preview.get("before", {}) as Dictionary).get("status", &""))) != &"destroyed"
	if not bool(options.get("defer_signal", false)):
		transaction_committed.emit(fact.duplicate(true))
	return fact.duplicate(true)


func publish_damage_fact(fact: Dictionary) -> void:
	transaction_committed.emit(fact.duplicate(true))


## Used only by BattleSystem's synchronous core-destruction coordinator when a
## later cross-state commit fails. It restores the exact copied rule states and
## revision without emitting a success fact.
func rollback_damage(fact: Dictionary) -> void:
	var target: Dictionary = fact.get("target", {})
	if StringName(str(target.get("target_kind", &""))) == &"structure_module":
		var module: Dictionary = fact.get("before", {})
		var restored_module: RefCounted = _module_from_snapshot(module)
		_modules_by_id[restored_module.module_id] = restored_module
		_module_id_by_canonical_edge[restored_module.canonical_edge] = restored_module.module_id
	else:
		var structure: Dictionary = fact.get("before", {})
		var restored_structure: RefCounted = _structure_from_snapshot(structure)
		_structures_by_id[restored_structure.structure_id] = restored_structure
		for occupied in restored_structure.footprint_cells:
			_structure_id_by_cell[occupied] = restored_structure.structure_id
		if restored_structure.source_runtime_id != 0:
			_structure_id_by_source_runtime_id[restored_structure.source_runtime_id] = restored_structure.structure_id
		for module: Dictionary in fact.get("before_modules", []):
			var restored_module: RefCounted = _module_from_snapshot(module)
			_modules_by_id[restored_module.module_id] = restored_module
			_module_id_by_canonical_edge[restored_module.canonical_edge] = restored_module.module_id
	_revision = int(fact.get("previous_revision", _revision))


func _structure_from_snapshot(raw: Dictionary) -> RefCounted:
	var inst: RefCounted = StructureStateClass.new(
		raw.get("structure_id", &""), raw.get("profile_id", &""), raw.get("owner_side", &"player"),
		raw.get("source_kind", &"card"), int(raw.get("source_runtime_id", 0)),
		raw.get("source_card_id", &""), raw.get("cell", Vector2i(-1, -1)),
		int(raw.get("minimum_foundation_height", 1)), int(raw.get("integrity_current", 1)),
		int(raw.get("integrity_max", 1)), int(raw.get("reserved_garrison_slots", 0)),
		raw.get("reserved_garrison_slot_defs", []), raw.get("module_ids", []),
		raw.get("foundation_state", FOUNDATION_STABLE), int(raw.get("foundation_observed_height", raw.get("minimum_foundation_height", 1))),
		raw.get("recovery_window_phase", WINDOW_NONE), int(raw.get("recovery_owner_turns_remaining", 0)),
		raw.get("undermined_cause", &""), raw.get("undermined_transaction_id", &""),
		int(raw.get("window_started_turn_serial", 0)),
	)
	inst.revision = int(raw.get("revision", 0))
	inst.footprint_cells.assign(raw.get("footprint_cells", [raw.cell]))
	return inst


func _module_from_snapshot(raw: Dictionary) -> RefCounted:
	var inst: RefCounted = ModuleStateClass.new(raw.get("module_id", &""), raw.get("structure_id", &""), raw.get("module_kind", &"wall"), raw.get("edge", &""), int(raw.get("integrity_current", 1)), int(raw.get("integrity_max", 1)), bool(raw.get("blocks_hostile_path", false)), bool(raw.get("allows_owner_passage", false)), raw.get("canonical_edge", &""))
	inst.revision = int(raw.get("revision", 0))
	return inst


func _damage_preview(target_ref: Dictionary, before: Dictionary, steps: int, is_core: bool) -> Dictionary:
	var current: int = int(before.get("integrity_current", 0))
	var actual_steps: int = mini(steps, current)
	var after: Dictionary = before.duplicate(true)
	after["integrity_current"] = current - actual_steps
	after["status"] = _damage_status_for(int(after.get("integrity_current", 0)), int(after.get("integrity_max", 1)), is_core)
	var result := {
		"ok": true,
		"reason_code": REASON_OK,
		"target": target_ref.duplicate(true),
		"before": before.duplicate(true),
		"after": after,
		"actual_steps": actual_steps,
		"breach_created": not is_core and int(after.get("integrity_current", 0)) == 0,
		"core_destroyed": is_core and int(after.get("integrity_current", 0)) == 0,
	}
	if is_core:
		var modules: Array[Dictionary] = []
		for module_id: StringName in before.get("module_ids", []):
			var module_state: Variant = _modules_by_id.get(module_id, null)
			if module_state != null:
				modules.append((module_state as RefCounted).snapshot())
		result["before_modules"] = modules
	return result


func _damage_status_for(current: int, maximum: int, is_core: bool) -> StringName:
	if current <= 0:
		return &"core_destroyed" if is_core else &"destroyed"
	if current >= maximum:
		return &"intact"
	if current == 1:
		return &"critical"
	return &"damaged"


## core/cell target ref：module revision 固定 -1。
func make_core_target_ref(cell: Vector2i, expected_terrain_revision: int = 0) -> Dictionary:
	var structure_id: Variant = _structure_id_by_cell.get(cell, null)
	if structure_id == null:
		return {}
	return {
		"target_kind": &"structure_core",
		"structure_id": structure_id,
		"module_id": &"",
		"cell": cell,
		"edge": &"",
		"expected_terrain_revision": expected_terrain_revision,
		"expected_structure_revision": _revision,
		"expected_module_revision": -1,
	}


## module target ref：携带独立 module revision。
func make_module_target_ref(cell: Vector2i, edge: StringName, expected_terrain_revision: int = 0) -> Dictionary:
	var structure_id: Variant = _structure_id_by_cell.get(cell, null)
	if structure_id == null:
		return {}
	var key: StringName = canonical_edge_key(cell, edge)
	var module_id: Variant = _module_id_by_canonical_edge.get(key, null)
	if module_id == null:
		return {}
	var module_state: Variant = _modules_by_id.get(module_id, null)
	if module_state == null:
		return {}
	return {
		"target_kind": &"structure_module",
		"structure_id": structure_id,
		"module_id": module_id,
		"cell": cell,
		"edge": edge,
		"expected_terrain_revision": expected_terrain_revision,
		"expected_structure_revision": _revision,
		"expected_module_revision": int((module_state as RefCounted).revision),
	}


func _invalid(reason_code: StringName, failed_index: int = -1) -> Dictionary:
	var result := {"ok": false, "reason_code": reason_code}
	if failed_index >= 0:
		result["failed_index"] = failed_index
	return result


func _get_replacement_targets(plan: Dictionary) -> Dictionary:
	var remove_value: Variant = plan.get("remove_source_runtime_ids", [])
	if not remove_value is Array:
		return _invalid(REASON_STRUCTURE_REPLACEMENT_INVALID)
	var runtime_ids: Array[int] = []
	var structure_ids: Array[StringName] = []
	var seen := {}
	for value: Variant in remove_value:
		if typeof(value) != TYPE_INT or int(value) <= 0 or seen.has(value):
			return _invalid(REASON_STRUCTURE_REPLACEMENT_INVALID)
		seen[value] = true
		var structure_id: StringName = get_source_structure_id(int(value))
		if structure_id == &"":
			return _invalid(REASON_STRUCTURE_TARGET_STALE)
		runtime_ids.append(int(value))
		structure_ids.append(structure_id)
	return {
		"ok": true,
		"reason_code": REASON_OK,
		"runtime_ids": runtime_ids,
		"structure_ids": structure_ids,
	}


## F1 restoration is independent of damage, breach and destruction semantics.
func get_repair_status(target_ref: Dictionary, steps: int) -> Dictionary:
	if steps <= 0:
		return _invalid(&"repair_amount_invalid")
	if target_ref.get("target_kind") != &"structure_module":
		return _invalid(&"repair_module_required")
	var cell: Variant = target_ref.get("cell")
	var structure_id := StringName(str(target_ref.get("structure_id", &"")))
	var module_id := StringName(str(target_ref.get("module_id", &"")))
	if not cell is Vector2i or structure_id == &"" or _structure_id_by_cell.get(cell) != structure_id:
		return _invalid(&"structure_target_stale")
	if not _structures_by_id.has(structure_id) or not _modules_by_id.has(module_id):
		return _invalid(&"structure_target_stale")
	var structure: Dictionary = _structures_by_id[structure_id].snapshot()
	var module: Dictionary = _modules_by_id[module_id].snapshot()
	if (int(structure.integrity_current) <= 0 or module.structure_id != structure_id
		or target_ref.get("edge") != module.edge
		or target_ref.get("expected_structure_revision") != _revision
		or target_ref.get("expected_module_revision") != module.revision):
		return _invalid(&"structure_target_stale")
	# Old board refs contain identity/revisions only. Optional enriched fields may
	# be checked, but authority always comes from the live structure/module.
	for key in ["source_runtime_id", "owner_side"]:
		if target_ref.has(key) and target_ref[key] != structure[key]:
			return _invalid(&"structure_target_stale")
	if target_ref.has("canonical_edge") and target_ref.canonical_edge != module.canonical_edge:
		return _invalid(&"structure_target_stale")
	if module.module_kind not in [&"wall", &"gatehouse"]:
		return _invalid(&"repair_module_required")
	var current := int(module.integrity_current)
	var maximum := int(module.integrity_max)
	if current <= 0:
		return _invalid(&"structure_module_destroyed")
	if current >= maximum:
		return _invalid(&"repair_already_full")
	var after := module.duplicate(true)
	after.integrity_current = current + mini(steps, maximum - current)
	after.status = _damage_status_for(after.integrity_current, maximum, false)
	var target := target_ref.duplicate(true)
	target.source_runtime_id = structure.source_runtime_id
	target.owner_side = structure.owner_side
	target.canonical_edge = module.canonical_edge
	return {"ok": true, "reason_code": &"ok", "operation": &"repair", "target": target,
		"before": module, "after": after, "actual_steps": after.integrity_current - current}

func commit_repair(target_ref: Dictionary, steps: int, options: Dictionary = {}) -> Dictionary:
	var fact := get_repair_status(target_ref, steps)
	if not fact.get("ok", false):
		return fact
	var module_id: StringName = fact.before.module_id
	var next_modules := _modules_by_id.duplicate()
	next_modules[module_id] = _modules_by_id[module_id].copy_with(int(fact.after.integrity_current))
	_modules_by_id = next_modules
	fact.previous_revision = _revision
	_revision += 1
	fact.revision = _revision
	fact.after = _modules_by_id[module_id].snapshot()
	if not options.get("defer_signal", false):
		publish_repair_fact(fact)
	return fact.duplicate(true)

func rollback_repair(fact: Dictionary) -> void:
	# Only an unpublished synchronous receipt may undo its own newest mutation.
	if fact.get("operation") != &"repair" or fact.get("revision", -1) != _revision:
		return
	var restored: RefCounted = _module_from_snapshot(fact.before)
	var next_modules := _modules_by_id.duplicate()
	next_modules[restored.module_id] = restored
	_modules_by_id = next_modules
	_revision = int(fact.previous_revision)

func publish_repair_fact(fact: Dictionary) -> void:
	if fact.get("ok", false) and fact.get("operation") == &"repair":
		transaction_committed.emit(fact.duplicate(true))
