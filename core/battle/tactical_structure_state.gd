extends RefCounted
class_name TacticalStructureState

## Elevated Grid Phase C — single structure core state (immutable semantics).
## Holds no Charge, OD, Depth, card cost or unit state. Snapshot results are copies.

var structure_id: StringName = &""
var profile_id: StringName = &""
var owner_side: StringName = &"player"
var source_kind: StringName = &"card"
var source_runtime_id: int = 0
var source_card_id: StringName = &""
var cell: Vector2i = Vector2i(-1, -1)
var minimum_foundation_height: int = 1
var foundation_state: StringName = &"stable"
var foundation_observed_height: int = 1
var recovery_window_phase: StringName = &"none"
var recovery_owner_turns_remaining: int = 0
var undermined_cause: StringName = &""
var undermined_transaction_id: StringName = &""
var window_started_turn_serial: int = 0
var integrity_current: int = 1
var integrity_max: int = 1
var status: StringName = &"intact"
var module_ids: Array[StringName] = []
var reserved_garrison_slots: int = 0
var reserved_garrison_slot_defs: Array[Dictionary] = []
var footprint_cells: Array[Vector2i] = []
var revision: int = 0


func _init(
	p_structure_id: StringName = &"",
	p_profile_id: StringName = &"",
	p_owner_side: StringName = &"player",
	p_source_kind: StringName = &"card",
	p_source_runtime_id: int = 0,
	p_source_card_id: StringName = &"",
	p_cell: Vector2i = Vector2i(-1, -1),
	p_minimum_foundation_height: int = 1,
	p_integrity_current: int = 1,
	p_integrity_max: int = 1,
	p_reserved_garrison_slots: int = 0,
	p_garrison_defs: Array = [],
	p_module_ids: Array = [],
	p_foundation_state: StringName = &"stable",
	p_foundation_observed_height: int = -999,
	p_recovery_window_phase: StringName = &"none",
	p_recovery_owner_turns_remaining: int = 0,
	p_undermined_cause: StringName = &"",
	p_undermined_transaction_id: StringName = &"",
	p_window_started_turn_serial: int = 0,
) -> void:
	structure_id = p_structure_id
	profile_id = p_profile_id
	owner_side = p_owner_side
	source_kind = p_source_kind
	source_runtime_id = p_source_runtime_id
	source_card_id = p_source_card_id
	cell = p_cell
	minimum_foundation_height = p_minimum_foundation_height
	foundation_state = p_foundation_state
	foundation_observed_height = p_minimum_foundation_height if p_foundation_observed_height == -999 else p_foundation_observed_height
	recovery_window_phase = p_recovery_window_phase
	recovery_owner_turns_remaining = p_recovery_owner_turns_remaining
	undermined_cause = p_undermined_cause
	undermined_transaction_id = p_undermined_transaction_id
	window_started_turn_serial = p_window_started_turn_serial
	integrity_current = p_integrity_current
	integrity_max = p_integrity_max
	reserved_garrison_slots = p_reserved_garrison_slots
	reserved_garrison_slot_defs = _copy_defs(p_garrison_defs)
	module_ids = _copy_names(p_module_ids)
	status = _derive_status()


func _derive_status() -> StringName:
	if integrity_current >= integrity_max:
		return &"intact"
	if integrity_current == 1:
		return &"critical"
	return &"damaged"


func snapshot() -> Dictionary:
	return {
		"structure_id": structure_id,
		"profile_id": profile_id,
		"owner_side": owner_side,
		"source_kind": source_kind,
		"source_runtime_id": source_runtime_id,
		"source_card_id": source_card_id,
		"cell": cell,
		"footprint_cells": footprint_cells.duplicate() if not footprint_cells.is_empty() else [cell],
		"minimum_foundation_height": minimum_foundation_height,
		"foundation_state": foundation_state,
		"foundation_observed_height": foundation_observed_height,
		"recovery_window_phase": recovery_window_phase,
		"recovery_owner_turns_remaining": recovery_owner_turns_remaining,
		"undermined_cause": undermined_cause,
		"undermined_transaction_id": undermined_transaction_id,
		"window_started_turn_serial": window_started_turn_serial,
		"integrity_current": integrity_current,
		"integrity_max": integrity_max,
		"status": status,
		"module_ids": module_ids.duplicate(),
		"reserved_garrison_slots": reserved_garrison_slots,
		"reserved_garrison_slot_defs": reserved_garrison_slot_defs.duplicate(true),
		"revision": revision,
	}


func copy_with(p_integrity_current: int) -> RefCounted:
	var inst = get_script().new(
		structure_id,
		profile_id,
		owner_side,
		source_kind,
		source_runtime_id,
		source_card_id,
		cell,
		minimum_foundation_height,
		p_integrity_current,
		integrity_max,
		reserved_garrison_slots,
		reserved_garrison_slot_defs,
		module_ids,
		foundation_state,
		foundation_observed_height,
		recovery_window_phase,
		recovery_owner_turns_remaining,
		undermined_cause,
		undermined_transaction_id,
		window_started_turn_serial,
	)
	inst.revision = revision + 1
	inst.footprint_cells = footprint_cells.duplicate()
	return inst


func copy_with_foundation(
	p_foundation_state: StringName,
	p_foundation_observed_height: int,
	p_recovery_window_phase: StringName,
	p_recovery_owner_turns_remaining: int,
	p_undermined_cause: StringName,
	p_undermined_transaction_id: StringName,
	p_window_started_turn_serial: int,
	p_revision: int,
) -> RefCounted:
	var inst = get_script().new(
		structure_id,
		profile_id,
		owner_side,
		source_kind,
		source_runtime_id,
		source_card_id,
		cell,
		minimum_foundation_height,
		integrity_current,
		integrity_max,
		reserved_garrison_slots,
		reserved_garrison_slot_defs,
		module_ids,
		p_foundation_state,
		p_foundation_observed_height,
		p_recovery_window_phase,
		p_recovery_owner_turns_remaining,
		p_undermined_cause,
		p_undermined_transaction_id,
		p_window_started_turn_serial,
	)
	inst.revision = p_revision
	inst.footprint_cells = footprint_cells.duplicate()
	return inst


func _copy_defs(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in raw:
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result


func _copy_names(raw: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for item in raw:
		result.append(StringName(str(item)))
	return result
