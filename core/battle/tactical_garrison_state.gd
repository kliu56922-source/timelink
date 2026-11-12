extends RefCounted
class_name TacticalGarrisonState

## Elevated Grid Phase D1 — one immutable-semantics garrison assignment.
## This value owns no unit combat state, movement, range, action cost, OD or Depth.

var structure_id: StringName = &""
var slot_id: StringName = &""
var unit_runtime_id: int = 0
var owner_side: StringName = &"player"
var parent_cell: Vector2i = Vector2i(-1, -1)
var socket_name: StringName = &""
var slot_role: StringName = &""
var support_module_id: StringName = &""
var platform_height_offset: int = 0
var entered_turn: int = 0
var state: StringName = &"active"
var assignment_revision: int = 0


func _init(
	p_structure_id: StringName = &"",
	p_slot_id: StringName = &"",
	p_unit_runtime_id: int = 0,
	p_owner_side: StringName = &"player",
	p_parent_cell: Vector2i = Vector2i(-1, -1),
	p_socket_name: StringName = &"",
	p_slot_role: StringName = &"",
	p_support_module_id: StringName = &"",
	p_platform_height_offset: int = 0,
	p_entered_turn: int = 0,
	p_state: StringName = &"active",
	p_assignment_revision: int = 0,
) -> void:
	structure_id = p_structure_id
	slot_id = p_slot_id
	unit_runtime_id = p_unit_runtime_id
	owner_side = p_owner_side
	parent_cell = p_parent_cell
	socket_name = p_socket_name
	slot_role = p_slot_role
	support_module_id = p_support_module_id
	platform_height_offset = p_platform_height_offset
	entered_turn = p_entered_turn
	state = p_state
	assignment_revision = p_assignment_revision


func snapshot() -> Dictionary:
	return {
		"structure_id": structure_id,
		"slot_id": slot_id,
		"unit_runtime_id": unit_runtime_id,
		"owner_side": owner_side,
		"parent_cell": parent_cell,
		"socket_name": socket_name,
		"slot_role": slot_role,
		"support_module_id": support_module_id,
		"platform_height_offset": platform_height_offset,
		"entered_turn": entered_turn,
		"state": state,
		"assignment_revision": assignment_revision,
	}


func copy_with_state(next_state: StringName, next_assignment_revision: int) -> RefCounted:
	return get_script().new(
		structure_id,
		slot_id,
		unit_runtime_id,
		owner_side,
		parent_cell,
		socket_name,
		slot_role,
		support_module_id,
		platform_height_offset,
		entered_turn,
		next_state,
		next_assignment_revision,
	)
