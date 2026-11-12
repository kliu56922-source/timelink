extends Node3D
class_name TacticalGarrisonPresenter
## Read-only Phase D1 garrison presentation. The BattleSystem remains the sole
## legality and mutation authority; this node owns only disposable visuals.

const LEGAL_COLOR := Color("#52E8F2")
const PENDING_COLOR := Color("#F4C95D")
const ACTIVE_COLOR := Color("#8FF4E8")
const BASE_RANGE_COLOR := Color("#667585")
const BONUS_RANGE_COLOR := Color("#55DFFF")

var _terrain_presenter: Node3D = null
var _structure_presenter: Node3D = null
var _reduced_motion := false
var _generation := 0
var _last_cleanup_reason: StringName = &""
var _mounted_visuals: Dictionary = {}
var _active_slots: Dictionary = {}
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	_ensure_roots()


func configure(terrain_presenter: Node3D, structure_presenter: Node3D) -> bool:
	_terrain_presenter = terrain_presenter
	_structure_presenter = structure_presenter
	_ensure_roots()
	return _terrain_presenter != null and is_instance_valid(_terrain_presenter) \
		and _structure_presenter != null and is_instance_valid(_structure_presenter)


func show_enter_candidates(unit_runtime_id: int, candidates: Array, reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion
	_generation += 1
	_clear_root("CandidateMarkerRoot")
	_clear_root("PendingMarkerRoot")
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index].duplicate(true)
		if not bool(candidate.get("ok", false)):
			continue
		var target_transform := _status_target_transform(candidate)
		var marker := _make_marker(
			"Candidate_%d" % index, LEGAL_COLOR, &"candidate", false
		)
		marker.global_transform = target_transform
		marker.set_meta("unit_runtime_id", unit_runtime_id)
		marker.set_meta("structure_id", candidate.get("structure_id", &""))
		marker.set_meta("slot_id", candidate.get("slot_id", &""))
		marker.set_meta("target_cell", candidate.get("target_cell", Vector2i(-1, -1)))
		(get_node("CandidateMarkerRoot") as Node3D).add_child(marker)


func show_pending(status: Dictionary, reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion
	_generation += 1
	_clear_root("CandidateMarkerRoot")
	_clear_root("PendingMarkerRoot")
	var marker := _make_marker("Pending", PENDING_COLOR, &"pending", true)
	(get_node("PendingMarkerRoot") as Node3D).add_child(marker)
	marker.global_transform = _status_target_transform(status)
	marker.set_meta("structure_id", status.get("structure_id", &""))
	marker.set_meta("slot_id", status.get("slot_id", &""))
	marker.set_meta("target_cell", status.get("target_cell", Vector2i(-1, -1)))


func apply_garrison_snapshot(snapshot: Dictionary, committed_fact: Dictionary, reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion
	_generation += 1
	var assignments_value: Variant = snapshot.get("assignments", {})
	var assignments: Dictionary = assignments_value if assignments_value is Dictionary else {}
	var next_slots: Dictionary = {}
	for raw_assignment in assignments.values():
		if not raw_assignment is Dictionary:
			continue
		var assignment: Dictionary = (raw_assignment as Dictionary).duplicate(true)
		var structure_id := StringName(str(assignment.get("structure_id", &"")))
		var slot_id := StringName(str(assignment.get("slot_id", &"")))
		var slot_key := "%s|%s" % [structure_id, slot_id]
		next_slots[slot_key] = assignment.duplicate(true)
		_set_structure_slot_state(structure_id, slot_id, true, StringName(str(assignment.get("state", &"active"))))
		var runtime_id := int(assignment.get("unit_runtime_id", 0))
		var visual := _mounted_visual_for(runtime_id)
		if visual != null:
			_mount_visual(visual, assignment)
	for previous_key in _active_slots:
		if next_slots.has(previous_key):
			continue
		var previous: Dictionary = _active_slots[previous_key]
		_set_structure_slot_state(
			StringName(str(previous.get("structure_id", &""))),
			StringName(str(previous.get("slot_id", &""))),
			false,
			&"available"
		)
	_active_slots = next_slots

	var fact_runtime_id := int(committed_fact.get("unit_runtime_id", 0))
	var fact_visual: Variant = committed_fact.get("unit_visual", null)
	if fact_runtime_id > 0 and fact_visual is Node3D and is_instance_valid(fact_visual):
		_mounted_visuals[fact_runtime_id] = weakref(fact_visual)
		var assignment: Dictionary = _assignment_for_runtime(assignments, fact_runtime_id)
		if not assignment.is_empty():
			_mount_visual(fact_visual as Node3D, assignment)
	var transaction_kind := StringName(str(committed_fact.get("transaction_kind", &"")))
	if transaction_kind in [&"garrison_exit", &"garrison_cleanup"] and fact_runtime_id > 0:
		_unmount_visual(fact_runtime_id)


func show_range_preview(preview: Dictionary, reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion
	_generation += 1
	_clear_root("BaseRangeMarkerRoot")
	_clear_root("BonusRangeMarkerRoot")
	_add_range_markers("BaseRangeMarkerRoot", preview.get("base_cells", []), BASE_RANGE_COLOR, &"base_range")
	_add_range_markers("BonusRangeMarkerRoot", preview.get("bonus_cells", []), BONUS_RANGE_COLOR, &"bonus_range")


func clear_transient(reason: StringName = &"cleanup") -> void:
	_last_cleanup_reason = reason
	_generation += 1
	_kill_tweens()
	for root_name in ["CandidateMarkerRoot", "PendingMarkerRoot", "BaseRangeMarkerRoot", "BonusRangeMarkerRoot"]:
		_clear_root(root_name)


func reset_for_stage() -> void:
	clear_transient(&"stage_reset")
	for slot_value in _active_slots.values():
		var slot: Dictionary = slot_value
		_set_structure_slot_state(
			StringName(str(slot.get("structure_id", &""))),
			StringName(str(slot.get("slot_id", &""))),
			false,
			&"available"
		)
	_active_slots.clear()
	for runtime_id in _mounted_visuals.keys():
		_unmount_visual(int(runtime_id))
	_mounted_visuals.clear()


func get_debug_snapshot() -> Dictionary:
	_ensure_roots()
	var mounted_ids: Array[int] = []
	for runtime_id in _mounted_visuals.keys():
		if _mounted_visual_for(int(runtime_id)) != null:
			mounted_ids.append(int(runtime_id))
	mounted_ids.sort()
	var candidate_count := get_node("CandidateMarkerRoot").get_child_count()
	var pending_count := get_node("PendingMarkerRoot").get_child_count()
	var base_count := get_node("BaseRangeMarkerRoot").get_child_count()
	var bonus_count := get_node("BonusRangeMarkerRoot").get_child_count()
	return {
		"candidate_marker_count": candidate_count,
		"pending_marker_count": pending_count,
		"base_range_marker_count": base_count,
		"bonus_range_marker_count": bonus_count,
		"transient_marker_count": candidate_count + pending_count + base_count + bonus_count,
		"mounted_visual_ids": mounted_ids,
		"active_slot_count": _active_slots.size(),
		"reduced_motion": _reduced_motion,
		"active_tweens": _active_tween_count(),
		"generation": _generation,
		"last_cleanup_reason": _last_cleanup_reason,
		"base_marker_color": BASE_RANGE_COLOR,
		"bonus_marker_color": BONUS_RANGE_COLOR,
	}.duplicate(true)


func _ensure_roots() -> void:
	for root_name in ["CandidateMarkerRoot", "PendingMarkerRoot", "BaseRangeMarkerRoot", "BonusRangeMarkerRoot"]:
		if get_node_or_null(root_name) == null:
			var marker_root := Node3D.new()
			marker_root.name = root_name
			add_child(marker_root)


func _clear_root(root_name: String) -> void:
	_ensure_roots()
	var marker_root := get_node(root_name)
	for child in marker_root.get_children():
		marker_root.remove_child(child)
		child.queue_free()


func _status_target_transform(status: Dictionary) -> Transform3D:
	var structure_id := StringName(str(status.get("structure_id", &"")))
	var socket_name := StringName(str(status.get("socket_name", &"Garrison0")))
	var mode := StringName(str(status.get("mode", &"enter")))
	if _structure_presenter != null and is_instance_valid(_structure_presenter) \
			and _structure_presenter.has_method("get_structure_socket_global_transform") \
			and structure_id != &"" and mode not in [&"exit", &"displaced"]:
		var structure_transform: Transform3D = _structure_presenter.call(
			"get_structure_socket_global_transform", structure_id, socket_name
		)
		if structure_transform != Transform3D():
			return structure_transform.translated_local(Vector3(0.0, 0.035, 0.0))
	var cell: Variant = status.get("target_cell", status.get("parent_cell", Vector2i(-1, -1)))
	if cell is Vector2i and _terrain_presenter != null and is_instance_valid(_terrain_presenter) \
			and _terrain_presenter.has_method("get_surface_anchor"):
		var anchor := _terrain_presenter.call("get_surface_anchor", cell) as Node3D
		if anchor != null and is_instance_valid(anchor):
			return anchor.global_transform.translated_local(Vector3(0.0, 0.035, 0.0))
	return global_transform


func _make_marker(marker_name: String, color: Color, marker_kind: StringName, ring: bool) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.set_meta("marker_kind", marker_kind)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22 if ring else 0.17
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.022
	mesh.radial_segments = 24
	marker.mesh = mesh
	marker.material_override = _marker_material(color, 0.58 if ring else 0.42)
	return marker


func _add_range_markers(root_name: String, cells_value: Variant, color: Color, marker_kind: StringName) -> void:
	if not cells_value is Array:
		return
	var seen: Dictionary = {}
	for raw_cell in cells_value:
		if not raw_cell is Vector2i or seen.has(raw_cell):
			continue
		seen[raw_cell] = true
		var marker := _make_marker("%s_%d_%d" % [marker_kind, raw_cell.x, raw_cell.y], color, marker_kind, false)
		(get_node(root_name) as Node3D).add_child(marker)
		marker.global_transform = _status_target_transform({"target_cell": raw_cell})


func _marker_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _set_structure_slot_state(structure_id: StringName, slot_id: StringName, active: bool, state: StringName) -> void:
	if _structure_presenter != null and is_instance_valid(_structure_presenter) \
			and _structure_presenter.has_method("set_garrison_slot_state"):
		_structure_presenter.call("set_garrison_slot_state", structure_id, slot_id, active, state)


func _assignment_for_runtime(assignments: Dictionary, runtime_id: int) -> Dictionary:
	for raw_assignment in assignments.values():
		if raw_assignment is Dictionary and int((raw_assignment as Dictionary).get("unit_runtime_id", 0)) == runtime_id:
			return (raw_assignment as Dictionary).duplicate(true)
	return {}


func _mounted_visual_for(runtime_id: int) -> Node3D:
	var visual_ref: Variant = _mounted_visuals.get(runtime_id, null)
	if visual_ref is WeakRef:
		var visual: Variant = (visual_ref as WeakRef).get_ref()
		if visual is Node3D and is_instance_valid(visual):
			return visual as Node3D
	return null


func _mount_visual(visual: Node3D, assignment: Dictionary) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if StringName(str(assignment.get("state", &"active"))) != &"active":
		return
	var socket_transform := Transform3D()
	if _structure_presenter != null and is_instance_valid(_structure_presenter) \
			and _structure_presenter.has_method("get_structure_socket_global_transform"):
		socket_transform = _structure_presenter.call(
			"get_structure_socket_global_transform",
			StringName(str(assignment.get("structure_id", &""))),
			StringName(str(assignment.get("socket_name", &"Garrison0")))
		)
	visual.global_transform = socket_transform if socket_transform != Transform3D() else _status_target_transform(assignment)
	visual.set_meta("garrison_presented", true)
	visual.set_meta("garrison_structure_id", assignment.get("structure_id", &""))
	visual.set_meta("garrison_slot_id", assignment.get("slot_id", &""))


func _unmount_visual(runtime_id: int) -> void:
	var visual := _mounted_visual_for(runtime_id)
	if visual != null:
		visual.remove_meta("garrison_presented")
		visual.remove_meta("garrison_structure_id")
		visual.remove_meta("garrison_slot_id")
	_mounted_visuals.erase(runtime_id)


func _active_tween_count() -> int:
	var count := 0
	for tween in _active_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			count += 1
	return count


func _kill_tweens() -> void:
	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()


func _exit_tree() -> void:
	_kill_tweens()
