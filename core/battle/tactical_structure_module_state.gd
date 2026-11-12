extends RefCounted
class_name TacticalStructureModuleState

## Elevated Grid Phase C — single structure edge module state (immutable semantics).
## Phase C only uses wall/gatehouse. Holds no Charge, OD, Depth, cost or unit state.

var module_id: StringName = &""
var structure_id: StringName = &""
var module_kind: StringName = &"wall"
var edge: StringName = &""
var canonical_edge: StringName = &""
var integrity_current: int = 1
var integrity_max: int = 1
var status: StringName = &"intact"
var blocks_hostile_path: bool = false
var allows_owner_passage: bool = false
var revision: int = 0


func _init(
	p_module_id: StringName = &"",
	p_structure_id: StringName = &"",
	p_module_kind: StringName = &"wall",
	p_edge: StringName = &"",
	p_integrity_current: int = 1,
	p_integrity_max: int = 1,
	p_blocks_hostile_path: bool = false,
	p_allows_owner_passage: bool = false,
	p_canonical_edge: StringName = &"",
) -> void:
	module_id = p_module_id
	structure_id = p_structure_id
	module_kind = p_module_kind
	edge = p_edge
	canonical_edge = p_canonical_edge
	integrity_current = p_integrity_current
	integrity_max = p_integrity_max
	blocks_hostile_path = p_blocks_hostile_path
	allows_owner_passage = p_allows_owner_passage
	status = _derive_status()


func _derive_status() -> StringName:
	if integrity_current <= 0:
		return &"destroyed"
	if integrity_current >= integrity_max:
		return &"intact"
	if integrity_current == 1:
		return &"critical"
	return &"damaged"


func snapshot() -> Dictionary:
	return {
		"module_id": module_id,
		"structure_id": structure_id,
		"module_kind": module_kind,
		"edge": edge,
		"canonical_edge": canonical_edge,
		"integrity_current": integrity_current,
		"integrity_max": integrity_max,
		"status": status,
		"blocks_hostile_path": blocks_hostile_path,
		"allows_owner_passage": allows_owner_passage,
		"revision": revision,
	}


func copy_with(p_integrity_current: int) -> RefCounted:
	var inst = get_script().new(
		module_id,
		structure_id,
		module_kind,
		edge,
		p_integrity_current,
		integrity_max,
		blocks_hostile_path,
		allows_owner_passage,
		canonical_edge,
	)
	inst.revision = revision + 1
	return inst
