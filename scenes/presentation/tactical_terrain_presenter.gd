extends Node3D
class_name TacticalTerrainPresenter

signal surface_positions_changed(changed_cells: Array[Vector2i])

const GRID_SIZE := 5
var _profile: RefCounted
var _base_transforms := {}
var _bases := {}
var _cell_roots := {}
var _surface_anchors := {}
var _cell_states := {}
var _active_batch_tween: Tween
var _feedback_generation := 0
var _active_batch_cells: Array[Vector2i] = []
var _last_batch_cells: Array[Vector2i] = []
var _last_batch_start_frame := -1
var _last_batch_generation := 0
var _last_snapshot_revision_by_cell := {}
var _last_batch_tracks: Array[Dictionary] = []
var _endpoint_emissions := 0
var _ignored_batch_completions := 0
var _process_emissions_by_generation := {}
var _endpoint_emissions_by_generation := {}
var _focus_cell := Vector2i(-1, -1)
var _cutaway_cells: Array[Vector2i] = []
var _cutaway_material: StandardMaterial3D
var _focus_camera: WeakRef
var _occlusion_refresh_generation := 0
var _reported_issue_keys: Dictionary = {}
var _last_snapshot_cells: Array[Dictionary] = []
var _preview_nodes: Array[Node3D] = []
var _last_preview_identity := &""

func _ready() -> void:
	_ensure_roots()

func _ensure_roots() -> void:
	for name in ["TerrainVisualRoot", "SurfaceAnchorRoot", "TerrainPreviewRoot", "TerrainFeedbackRoot"]:
		if get_node_or_null(NodePath(name)) == null:
			var child := Node3D.new()
			child.name = name
			add_child(child)

func configure(base_anchor_resolver: Callable, profile: RefCounted) -> bool:
	if not base_anchor_resolver.is_valid() or profile == null:
		return false
	var transforms := {}
	var bases := {}
	for rank in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var cell := Vector2i(column, rank)
			var anchor := base_anchor_resolver.call(cell) as Node3D
			if anchor == null:
				return false
			transforms[cell] = anchor.global_transform
			bases[cell] = anchor.global_position
	_base_transforms = transforms
	_bases = bases
	_profile = profile
	_ensure_roots()
	return true

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE

func _axis(cell: Vector2i, offset: Vector2i) -> Vector3:
	var next := cell + offset
	var previous := cell - offset
	if _bases.has(next):
		return (_bases[next] as Vector3) - (_bases[cell] as Vector3)
	if _bases.has(previous):
		return (_bases[cell] as Vector3) - (_bases[previous] as Vector3)
	return Vector3.ZERO

func _validate_snapshot(snapshot: Dictionary) -> Array[Dictionary]:
	if _profile == null or _bases.size() != GRID_SIZE * GRID_SIZE:
		return []
	var raw_cells = snapshot.get("cells", null)
	if not raw_cells is Array or raw_cells.size() != GRID_SIZE * GRID_SIZE:
		return []
	var validated: Array[Dictionary] = []
	var seen := {}
	for raw in raw_cells:
		if not raw is Dictionary:
			return []
		var cell = raw.get("cell", null)
		var height = raw.get("height", null)
		if not cell is Vector2i or not _in_bounds(cell) or seen.has(cell) or not (height is int) or int(height) < 0 or int(height) > 2 or not raw.get("surface", null) is StringName or not raw.get("revision", null) is int:
			return []
		seen[cell] = true
		validated.append(raw.duplicate(true))
	return validated

func apply_board_snapshot(snapshot: Dictionary, committed_fact: Dictionary = {}, reduced_motion: bool = false) -> Dictionary:
	var cells := _validate_snapshot(snapshot)
	if cells.is_empty():
		_report_issue(&"invalid_snapshot", "Terrain presentation ignored an incomplete or malformed copied snapshot.")
		return {"ok": false, "reason_code": &"invalid_snapshot"}
	var geometries := {}
	for cell_data in cells:
		var geometry := _geometry_for(cell_data["cell"] as Vector2i)
		if geometry.is_empty():
			return {"ok": false, "reason_code": &"degenerate_geometry"}
		geometries[cell_data["cell"]] = geometry
	for cell_data in cells:
		var incoming_revision := int(cell_data["revision"])
		var applied_revision: Variant = _last_snapshot_revision_by_cell.get(cell_data["cell"], null)
		if applied_revision != null and incoming_revision < int(applied_revision):
			return {"ok": false, "reason_code": &"stale_snapshot_revision"}
	if not _last_snapshot_cells.is_empty() and cells == _last_snapshot_cells:
		return {"ok": true, "changed_cells": []}
	var fact_changed := _changed_cells_from_fact(committed_fact, cells)
	var prior_states := _cell_states.duplicate(true)
	var superseded_batch_cells: Array[Vector2i] = _active_batch_cells.duplicate()
	_active_batch_cells.clear()
	if _active_batch_tween != null and _active_batch_tween.is_valid():
		_active_batch_tween.kill()
		_active_batch_tween = null
		set_process(false)
	for cell_data in cells:
		var cell: Vector2i = cell_data["cell"]
		if cell in superseded_batch_cells or not _cell_visual_matches(cell_data):
			_apply_cell(cell_data, geometries[cell])
		else:
			_update_cell_revision(cell_data)
		_last_snapshot_revision_by_cell[cell] = int(cell_data["revision"])
	_last_snapshot_cells = cells.duplicate(true)
	if _focus_camera != null:
		var focus_camera: Camera3D = _focus_camera.get_ref() as Camera3D
		if focus_camera != null and is_instance_valid(focus_camera):
			_cutaway_cells.clear()
			refresh_occlusion(focus_camera)
	if _in_bounds(_focus_cell):
		_refresh_height_label()
	if not fact_changed.is_empty() and not reduced_motion:
		_begin_batch(fact_changed, prior_states)
		_sync_height_label_position()
		_show_commit_feedback(fact_changed, false)
	else:
		_last_batch_cells = fact_changed.duplicate()
		set_process(false)
		if reduced_motion and not fact_changed.is_empty():
			_show_commit_feedback(fact_changed, true)
	var emitted_cells: Array[Vector2i] = []
	if committed_fact.is_empty():
		for cell_data in cells:
			emitted_cells.append(cell_data["cell"] as Vector2i)
		surface_positions_changed.emit(emitted_cells)
	elif reduced_motion and not fact_changed.is_empty():
		emitted_cells = fact_changed.duplicate()
		surface_positions_changed.emit(emitted_cells)
	return {"ok": true, "changed_cells": emitted_cells if not emitted_cells.is_empty() else _last_batch_cells.duplicate()}

func _changed_cells_from_fact(committed_fact: Dictionary, cells: Array[Dictionary]) -> Array[Vector2i]:
	if not bool(committed_fact.get("ok", false)) or not committed_fact.get("changes", null) is Array:
		return []
	var available := {}
	for cell_data in cells:
		available[cell_data["cell"]] = true
	var changed: Array[Vector2i] = []
	for change in committed_fact["changes"]:
		if not change is Dictionary or not change.get("cell", null) is Vector2i:
			return []
		var cell: Vector2i = change["cell"]
		if not available.has(cell) or cell in changed:
			return []
		changed.append(cell)
	return changed

func _begin_batch(changed: Array[Vector2i], prior_states: Dictionary) -> void:
	_active_batch_cells = changed.duplicate()
	_last_batch_cells = changed.duplicate()
	_last_batch_start_frame = Engine.get_process_frames()
	_last_batch_generation += 1
	_last_batch_tracks.clear()
	var generation := _last_batch_generation
	_process_emissions_by_generation[generation] = 0
	_endpoint_emissions_by_generation[generation] = 0
	var batch_tween := create_tween().bind_node(self).set_parallel(true)
	_active_batch_tween = batch_tween
	for cell in changed:
		var old_height := int((prior_states.get(cell, {}) as Dictionary).get("height", 0))
		var new_height := int((_cell_states.get(cell, {}) as Dictionary).get("height", 0))
		var duration: float = _profile.get_terrain_raise_seconds() if new_height >= old_height else _profile.get_terrain_lower_seconds()
		_animate_cell(cell, old_height, new_height, duration)
	batch_tween.finished.connect(func() -> void: _finish_batch(generation, batch_tween))
	set_process(true)

func _animate_cell(cell: Vector2i, old_height: int, new_height: int, duration: float) -> void:
	var root := _cell_roots.get(cell, null) as Node3D
	var anchor := _surface_anchors.get(cell, null) as Marker3D
	if root == null or anchor == null:
		return
	var state := _cell_states.get(cell, {}) as Dictionary
	var step := float(state.get("visual_height_world", 0.0)) / maxf(float(new_height), 1.0)
	var old_visual := step * float(old_height)
	var target_anchor := anchor.global_position
	anchor.global_position = (_bases[cell] as Vector3) + Vector3.UP * old_visual
	var ease := Tween.EASE_OUT if new_height >= old_height else Tween.EASE_IN_OUT
	_tween_property(anchor, "global_position", target_anchor, duration, ease, cell)
	for child in root.get_children():
		if child is Node3D and (str(child.name).begins_with("Glyph_") or child.name == "HeightDoubleBorder"):
			var shape_root := child as Node3D
			var target_shape_position := shape_root.position
			shape_root.position = Vector3(target_shape_position.x, old_visual + target_shape_position.y - float(state.get("visual_height_world", 0.0)), target_shape_position.z)
			_tween_property(shape_root, "position", target_shape_position, duration, ease, cell)
			continue
		if not child is MeshInstance3D:
			continue
		var mesh_node := child as MeshInstance3D
		var target_position := mesh_node.position
		var start_position := target_position
		if mesh_node.name == "Cap" or mesh_node.name == "Edge" or str(mesh_node.name).begins_with("CapOutline_"):
			start_position.y = old_visual + (target_position.y - float(state.get("visual_height_world", 0.0)))
		elif str(mesh_node.name).begins_with("HeightBand_"):
			start_position.y = minf(target_position.y, old_visual)
		elif mesh_node.name == "Body":
			start_position.y = old_visual * 0.5
			var start_scale := mesh_node.scale
			start_scale.y = old_visual / maxf(float(state.get("visual_height_world", 0.0)), 0.001)
			mesh_node.scale = start_scale
			_tween_property(mesh_node, "scale", Vector3.ONE, duration, ease, cell)
		mesh_node.position = start_position
		_tween_property(mesh_node, "position", target_position, duration, ease, cell)

func _tween_property(target: Object, property: NodePath, value: Variant, duration: float, ease: Tween.EaseType, cell: Vector2i) -> void:
	_active_batch_tween.tween_property(target, property, value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	_last_batch_tracks.append({"cell": cell, "property": String(property), "start_frame": _last_batch_start_frame, "duration": duration, "ease": ease, "transition": Tween.TRANS_CUBIC})

func _process(_delta: float) -> void:
	if _active_batch_tween != null and _active_batch_tween.is_valid() and _active_batch_tween.is_running():
		_sync_height_label_position()
		surface_positions_changed.emit(_active_batch_cells.duplicate())
		_process_emissions_by_generation[_last_batch_generation] = int(_process_emissions_by_generation.get(_last_batch_generation, 0)) + 1

func _finish_batch(generation: int, tween: Tween) -> void:
	if generation != _last_batch_generation or tween != _active_batch_tween or _active_batch_cells.is_empty():
		_ignored_batch_completions += 1
		return
	surface_positions_changed.emit(_active_batch_cells.duplicate())
	_endpoint_emissions += 1
	_endpoint_emissions_by_generation[generation] = int(_endpoint_emissions_by_generation.get(generation, 0)) + 1
	_sync_height_label_position()
	_show_commit_feedback(_active_batch_cells, true)
	_active_batch_cells.clear()
	_active_batch_tween = null
	set_process(false)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _report_issue(key: StringName, message: String) -> void:
	if _reported_issue_keys.has(key):
		return
	_reported_issue_keys[key] = message
	push_warning("[TERRAIN PRESENTATION] %s" % message)

func _show_commit_feedback(cells: Array[Vector2i], landing: bool) -> void:
	_feedback_generation += 1
	_clear_commit_feedback_nodes()
	var feedback_root := get_node_or_null(NodePath("TerrainFeedbackRoot")) as Node3D
	if feedback_root == null:
		return
	var color: Color = _profile.get_terrain_feedback_color(&"legal" if landing else &"pending")
	for cell in cells:
		if not _cell_states.has(cell):
			continue
		var state := _cell_states[cell] as Dictionary
		var geometry := _geometry_for(cell)
		if geometry.is_empty():
			continue
		var feedback := Node3D.new()
		feedback.name = "CommitFeedback_%d_%d" % [cell.x, cell.y]
		feedback_root.add_child(feedback)
		feedback.global_transform = Transform3D(geometry["basis"] as Basis, get_surface_world_position(cell) + Vector3.UP * 0.018)
		var footprint_x := float(state.get("footprint_column", 0.1))
		var footprint_z := float(state.get("footprint_rank", 0.1))
		_add_border_shape(feedback, "Landing" if landing else "Flash", footprint_x * (0.74 if landing else 0.88), footprint_z * (0.68 if landing else 0.82), maxf(minf(footprint_x, footprint_z) * 0.025, 0.006), _material(color))
	var generation := _feedback_generation
	get_tree().create_timer(_profile.get_terrain_feedback_seconds()).timeout.connect(func() -> void: _finish_commit_feedback(generation), CONNECT_ONE_SHOT)

func _finish_commit_feedback(generation: int) -> void:
	if generation != _feedback_generation:
		return
	_clear_commit_feedback_nodes()

func _clear_commit_feedback_nodes() -> void:
	var feedback_root := get_node_or_null(NodePath("TerrainFeedbackRoot"))
	if feedback_root == null:
		return
	for child in feedback_root.get_children():
		if child.name == "HeightLabel":
			continue
		feedback_root.remove_child(child)
		child.queue_free()

func _get_cutaway_material() -> StandardMaterial3D:
	if _cutaway_material != null:
		return _cutaway_material
	if _profile == null:
		return null
	var size := maxi(_profile.get_cutaway_checker_size(), 1)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if (x + y) % 2 == 0 else 0.0))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = _profile.get_cutaway_alpha_scissor_threshold()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cutaway_material = material
	return _cutaway_material

func _mesh_node(name: String, mesh: Mesh, material: Material, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.position = position
	return node

func _geometry_for(cell: Vector2i) -> Dictionary:
	var column_axis := _axis(cell, Vector2i(1, 0))
	var rank_axis := _axis(cell, Vector2i(0, 1))
	var planar_column := Vector3(column_axis.x, 0.0, column_axis.z)
	var planar_rank := Vector3(rank_axis.x, 0.0, rank_axis.z)
	if planar_column.length() < 0.001 or planar_rank.length() < 0.001:
		return {}
	var x_axis := planar_column.normalized()
	var z_axis := (planar_rank - x_axis * planar_rank.dot(x_axis)).normalized()
	if z_axis.length() < 0.001:
		return {}
	return {"basis": Basis(x_axis, Vector3.UP, z_axis), "column_length": planar_column.length(), "rank_length": planar_rank.length()}

func _cell_visual_matches(data: Dictionary) -> bool:
	var cell: Vector2i = data["cell"]
	var state := _cell_states.get(cell, {}) as Dictionary
	return not state.is_empty() \
		and _cell_roots.has(cell) and is_instance_valid(_cell_roots[cell]) \
		and _surface_anchors.has(cell) and is_instance_valid(_surface_anchors[cell]) \
		and int(state.get("height", -1)) == int(data["height"]) \
		and state.get("surface", &"") == data["surface"]

func _update_cell_revision(data: Dictionary) -> void:
	var cell: Vector2i = data["cell"]
	var state := _cell_states.get(cell, {}) as Dictionary
	state["revision"] = int(data["revision"])
	_cell_states[cell] = state

func _apply_cell(data: Dictionary, geometry: Dictionary) -> void:
	_ensure_roots()
	var cell: Vector2i = data["cell"]
	var basis: Basis = geometry["basis"]
	var footprint_column: float = float(geometry["column_length"]) * _profile.get_terrain_footprint_ratio()
	var footprint_rank: float = float(geometry["rank_length"]) * _profile.get_terrain_footprint_ratio()
	var level_step: float = minf(float(geometry["column_length"]), float(geometry["rank_length"])) * _profile.get_terrain_level_step_ratio()
	var height := int(data["height"])
	var visual_height: float = float(height) * level_step
	var visual_root := _cell_roots.get(cell, null) as Node3D
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "Cell_%d_%d" % [cell.x, cell.y]
		get_node("TerrainVisualRoot").add_child(visual_root)
		_cell_roots[cell] = visual_root
	var anchor := _surface_anchors.get(cell, null) as Marker3D
	if anchor == null:
		anchor = Marker3D.new()
		anchor.name = "Surface_%d_%d" % [cell.x, cell.y]
		get_node("SurfaceAnchorRoot").add_child(anchor)
		_surface_anchors[cell] = anchor
	visual_root.global_transform = Transform3D(basis, _bases[cell] as Vector3)
	anchor.global_position = (_bases[cell] as Vector3) + Vector3.UP * visual_height
	_clear_children(visual_root)
	if height > 0:
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(footprint_column, maxf(level_step * _profile.get_terrain_cap_thickness_ratio(), 0.005), footprint_rank)
		var cap := _mesh_node("Cap", cap_mesh, _material(_profile.get_terrain_cap_color()), Vector3.UP * (visual_height - cap_mesh.size.y * 0.5))
		visual_root.add_child(cap)
	else:
		_add_cap_outline(visual_root, footprint_column, footprint_rank, visual_height)
	var body_visible := height > 0
	if body_visible:
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(footprint_column, visual_height, footprint_rank)
		visual_root.add_child(_mesh_node("Body", body_mesh, _material(_profile.get_terrain_body_color()), Vector3.UP * visual_height * 0.5))
	for index in range(height):
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(footprint_column * 1.01, maxf(level_step * 0.04, 0.006), footprint_rank * 1.01)
		visual_root.add_child(_mesh_node("HeightBand_%d" % index, band_mesh, _material(_profile.get_terrain_height_band_color()), Vector3.UP * (level_step * float(index + 1))))
	if height > 0:
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(footprint_column * 1.02, 0.005, footprint_rank * 1.02)
		visual_root.add_child(_mesh_node("Edge", edge_mesh, _material(_profile.get_terrain_edge_color()), Vector3.UP * (visual_height + 0.004)))
	if height == 2:
		_add_height_double_border(visual_root, footprint_column, footprint_rank, visual_height)
	var surface := data["surface"] as StringName
	var glyph: StringName = _profile.get_surface_glyph(surface)
	if glyph == &"":
		_report_issue(StringName("unknown_surface:%s" % surface), "Terrain presentation used neutral glyph for unknown surface '%s'." % surface)
		glyph = &"single_border"
	_add_surface_glyph(visual_root, glyph, footprint_column, footprint_rank, visual_height)
	_cell_states[cell] = {"height": height, "surface": data["surface"], "revision": data["revision"], "visual_height_world": visual_height, "target_world_position": anchor.global_position, "footprint_column": footprint_column, "footprint_rank": footprint_rank, "height_band_count": height, "body_visible": body_visible}


func _add_cap_outline(parent: Node3D, column_span: float, rank_span: float, visual_height: float) -> void:
	var border_width := maxf(minf(column_span, rank_span) * 0.035, 0.008)
	var material := _material(_profile.get_terrain_edge_color())
	var long_mesh := BoxMesh.new()
	long_mesh.size = Vector3(column_span, 0.005, border_width)
	var short_mesh := BoxMesh.new()
	short_mesh.size = Vector3(border_width, 0.005, maxf(rank_span - border_width * 2.0, border_width))
	var height_offset := visual_height + 0.004
	var rank_offset := rank_span * 0.5 - border_width * 0.5
	var column_offset := column_span * 0.5 - border_width * 0.5
	parent.add_child(_mesh_node("CapOutline_North", long_mesh, material, Vector3(0.0, height_offset, -rank_offset)))
	parent.add_child(_mesh_node("CapOutline_South", long_mesh, material, Vector3(0.0, height_offset, rank_offset)))
	parent.add_child(_mesh_node("CapOutline_West", short_mesh, material, Vector3(-column_offset, height_offset, 0.0)))
	parent.add_child(_mesh_node("CapOutline_East", short_mesh, material, Vector3(column_offset, height_offset, 0.0)))


func _add_surface_glyph(parent: Node3D, glyph: StringName, column_span: float, rank_span: float, visual_height: float) -> void:
	if glyph == &"":
		return
	var glyph_root := Node3D.new()
	glyph_root.name = "Glyph_%s" % glyph
	glyph_root.position = Vector3.UP * (visual_height + 0.009)
	parent.add_child(glyph_root)
	var edge_material := _material(_profile.get_terrain_edge_color())
	var thin := maxf(minf(column_span, rank_span) * 0.025, 0.006)
	match glyph:
		&"single_border":
			_add_border_shape(glyph_root, "Single", column_span * 0.86, rank_span * 0.78, thin, edge_material)
		&"corner_brackets":
			_add_corner_brackets(glyph_root, column_span, rank_span, thin, edge_material)
		&"double_border":
			_add_border_shape(glyph_root, "Outer", column_span * 0.90, rank_span * 0.82, thin, edge_material)
			_add_border_shape(glyph_root, "Inner", column_span * 0.68, rank_span * 0.58, thin, edge_material)
		&"corner_clamps":
			_add_corner_clamps(glyph_root, column_span, rank_span, thin, edge_material)
		&"heat_hatch":
			_add_heat_hatch(glyph_root, column_span, rank_span, thin)
		&"broken_border":
			_add_broken_border(glyph_root, column_span, rank_span, thin, edge_material)
		&"dashed_notch":
			_add_dashed_notch(glyph_root, column_span, rank_span, thin, edge_material)
		_:
			_add_border_shape(glyph_root, "Neutral", column_span * 0.86, rank_span * 0.78, thin, edge_material)

func _add_box_shape(parent: Node3D, name: String, size: Vector3, position: Vector3, material: Material, yaw: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := _mesh_node(name, mesh, material, position)
	shape.rotation.y = yaw
	parent.add_child(shape)

func _add_border_shape(parent: Node3D, prefix: String, width: float, depth: float, thickness: float, material: Material) -> void:
	var y := 0.0
	_add_box_shape(parent, "%sNorth" % prefix, Vector3(width, 0.007, thickness), Vector3(0.0, y, -depth * 0.5), material)
	_add_box_shape(parent, "%sSouth" % prefix, Vector3(width, 0.007, thickness), Vector3(0.0, y, depth * 0.5), material)
	_add_box_shape(parent, "%sWest" % prefix, Vector3(thickness, 0.007, depth), Vector3(-width * 0.5, y, 0.0), material)
	_add_box_shape(parent, "%sEast" % prefix, Vector3(thickness, 0.007, depth), Vector3(width * 0.5, y, 0.0), material)

func _add_corner_brackets(parent: Node3D, width: float, depth: float, thickness: float, material: Material) -> void:
	var arm_x := width * 0.22
	var arm_z := depth * 0.22
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := "%s%s" % ["W" if sx < 0.0 else "E", "N" if sz < 0.0 else "S"]
			_add_box_shape(parent, "Bracket%sX" % corner, Vector3(arm_x, 0.007, thickness), Vector3(sx * (width * 0.40 - arm_x * 0.5), 0.0, sz * depth * 0.40), material)
			_add_box_shape(parent, "Bracket%sZ" % corner, Vector3(thickness, 0.007, arm_z), Vector3(sx * width * 0.40, 0.0, sz * (depth * 0.40 - arm_z * 0.5)), material)

func _add_corner_clamps(parent: Node3D, width: float, depth: float, thickness: float, material: Material) -> void:
	var clamp_size := maxf(minf(width, depth) * 0.16, thickness * 2.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box_shape(parent, "Clamp_%s_%s" % ["W" if sx < 0.0 else "E", "N" if sz < 0.0 else "S"], Vector3(clamp_size, 0.010, clamp_size), Vector3(sx * width * 0.34, 0.0, sz * depth * 0.34), material)

func _add_heat_hatch(parent: Node3D, width: float, depth: float, thickness: float) -> void:
	var heat_material := _material(Color("#F28C28"))
	for index in range(-1, 2):
		_add_box_shape(parent, "HeatHatch_%d" % index, Vector3(width * 0.50, 0.008, thickness), Vector3(float(index) * width * 0.18, 0.0, 0.0), heat_material, deg_to_rad(28.0))
	_add_box_shape(parent, "HeatCore", Vector3(depth * 0.16, 0.012, depth * 0.16), Vector3.ZERO, heat_material, deg_to_rad(45.0))

func _add_broken_border(parent: Node3D, width: float, depth: float, thickness: float, material: Material) -> void:
	var half_segment := width * 0.30
	_add_box_shape(parent, "BrokenNorthW", Vector3(half_segment, 0.007, thickness), Vector3(-width * 0.25, 0.0, -depth * 0.38), material)
	_add_box_shape(parent, "BrokenNorthE", Vector3(half_segment, 0.007, thickness), Vector3(width * 0.25, 0.0, -depth * 0.38), material)
	_add_box_shape(parent, "BrokenSouthW", Vector3(half_segment * 0.72, 0.007, thickness), Vector3(-width * 0.30, 0.0, depth * 0.38), material)
	_add_box_shape(parent, "BrokenSouthE", Vector3(half_segment * 0.72, 0.007, thickness), Vector3(width * 0.30, 0.0, depth * 0.38), material)
	_add_box_shape(parent, "CrackA", Vector3(width * 0.34, 0.009, thickness), Vector3.ZERO, material, deg_to_rad(35.0))
	_add_box_shape(parent, "CrackB", Vector3(width * 0.28, 0.009, thickness), Vector3(width * 0.05, 0.0, 0.0), material, deg_to_rad(-35.0))

func _add_dashed_notch(parent: Node3D, width: float, depth: float, thickness: float, material: Material) -> void:
	for index in range(-2, 3):
		_add_box_shape(parent, "LowerDash_%d" % index, Vector3(width * 0.12, 0.007, thickness), Vector3(float(index) * width * 0.18, 0.0, depth * 0.34), material)
	_add_box_shape(parent, "DownNotchLeft", Vector3(depth * 0.20, 0.009, thickness), Vector3(-width * 0.06, 0.0, 0.0), material, deg_to_rad(45.0))
	_add_box_shape(parent, "DownNotchRight", Vector3(depth * 0.20, 0.009, thickness), Vector3(width * 0.06, 0.0, 0.0), material, deg_to_rad(-45.0))

func _add_height_double_border(parent: Node3D, width: float, depth: float, visual_height: float) -> void:
	var root := Node3D.new()
	root.name = "HeightDoubleBorder"
	root.position = Vector3.UP * (visual_height + 0.012)
	parent.add_child(root)
	_add_border_shape(root, "HeightInner", width * 0.72, depth * 0.64, maxf(minf(width, depth) * 0.018, 0.005), _material(_profile.get_terrain_height_band_color()))

func get_surface_anchor(cell: Vector2i) -> Node3D: return _surface_anchors.get(cell, null) as Node3D
func get_surface_world_position(cell: Vector2i) -> Vector3:
	var anchor := get_surface_anchor(cell)
	return anchor.global_position if anchor != null else Vector3.ZERO
func get_proposed_surface_transform(cell: Vector2i, target_height: int) -> Transform3D:
	if not _in_bounds(cell) or _profile == null or not _bases.has(cell) or target_height < 0 or target_height > 2:
		return Transform3D.IDENTITY
	var geometry := _geometry_for(cell)
	if geometry.is_empty(): return Transform3D.IDENTITY
	var level_step: float = minf(float(geometry["column_length"]), float(geometry["rank_length"])) * float(_profile.get_terrain_level_step_ratio())
	return Transform3D(geometry["basis"] as Basis, (_bases[cell] as Vector3) + Vector3.UP * level_step * float(target_height))
func get_surface_target_world_position(cell: Vector2i) -> Vector3: return get_cell_visual_state(cell).get("target_world_position", get_surface_world_position(cell)) as Vector3
func get_visual_height_world(cell: Vector2i) -> float: return float(get_cell_visual_state(cell).get("visual_height_world", 0.0))
func get_cell_visual_state(cell: Vector2i) -> Dictionary: return (_cell_states.get(cell, {}) as Dictionary).duplicate(true)
func get_column_count() -> int: return _cell_roots.size()
func get_surface_anchor_count() -> int: return _surface_anchors.size()
func get_active_tween_count() -> int: return 1 if _active_batch_tween != null and _active_batch_tween.is_valid() and _active_batch_tween.is_running() else 0
func show_height_preview(preview_fact: Dictionary) -> Dictionary:
	if not preview_fact is Dictionary:
		return {"ok": false, "reason_code": &"invalid_preview"}
	var cell = preview_fact.get("cell", null)
	var current_height = preview_fact.get("current_height", null)
	var proposed_height = preview_fact.get("proposed_height", null)
	var visual_state = preview_fact.get("visual_state", null)
	var preview_id = preview_fact.get("preview_id", null)
	var expected_revision = preview_fact.get("expected_revision", null)
	if not cell is Vector2i or not _in_bounds(cell) or not current_height is int or not proposed_height is int or not visual_state is StringName or preview_id == null or not expected_revision is int or not visual_state in [&"legal", &"pending", &"invalid"]:
		return {"ok": false, "reason_code": &"invalid_preview"}
	if int(current_height) < 0 or int(current_height) > 2 or int(proposed_height) < 0 or int(proposed_height) > 2:
		return {"ok": false, "reason_code": &"invalid_preview_height"}
	var state := _cell_states.get(cell, {}) as Dictionary
	if state.is_empty() or int(state.get("revision", -1)) != int(expected_revision):
		clear_height_preview()
		return {"ok": false, "reason_code": &"stale_preview"}
	var identity := StringName("%s:%s:%s:%s:%s" % [preview_id, cell, current_height, proposed_height, visual_state])
	if identity == _last_preview_identity:
		return {"ok": true, "preview_id": preview_id, "node_count": _preview_nodes.size()}
	clear_height_preview()
	var root := get_node_or_null(NodePath("TerrainPreviewRoot")) as Node3D
	if root == null:
		return {"ok": false, "reason_code": &"preview_root_missing"}
	var color: Color = _profile.get_terrain_feedback_color(visual_state)
	var geometry := _geometry_for(cell)
	if geometry.is_empty():
		return {"ok": false, "reason_code": &"degenerate_geometry"}
	var preview_root := Node3D.new()
	preview_root.name = "Preview_%s" % preview_id
	preview_root.global_transform = Transform3D(geometry["basis"] as Basis, _bases[cell] as Vector3)
	root.add_child(preview_root)
	var footprint_x := float(state.get("footprint_column", 0.1))
	var footprint_z := float(state.get("footprint_rank", 0.1))
	var step := float(state.get("visual_height_world", 0.0)) / maxf(float(current_height), 1.0)
	if is_zero_approx(step):
		step = minf(float(geometry["column_length"]), float(geometry["rank_length"])) * _profile.get_terrain_level_step_ratio()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(footprint_x * 0.86, 0.006, footprint_z * 0.86)
	preview_root.add_child(_mesh_node("ProposedCap", cap_mesh, _material(color), Vector3.UP * (step * float(proposed_height) + 0.012)))
	var state_mesh := BoxMesh.new()
	if visual_state == &"legal":
		state_mesh.size = Vector3(footprint_x * 0.94, 0.004, footprint_z * 0.05)
		preview_root.add_child(_mesh_node("LegalOutline", state_mesh, _material(color), Vector3.UP * (step * float(proposed_height) + 0.017)))
	elif visual_state == &"pending":
		state_mesh.size = Vector3(footprint_x * 0.16, 0.012, footprint_z * 0.16)
		preview_root.add_child(_mesh_node("PendingMarker", state_mesh, _material(color), Vector3.UP * (step * float(proposed_height) + 0.020)))
	else:
		state_mesh.size = Vector3(footprint_x * 0.78, 0.005, footprint_z * 0.06)
		preview_root.add_child(_mesh_node("InvalidCross", state_mesh, _material(color), Vector3.UP * (step * float(proposed_height) + 0.018)))
	if int(proposed_height) > int(current_height):
		var ghost_mesh := BoxMesh.new()
		ghost_mesh.size = Vector3(footprint_x * 0.76, maxf(step * float(proposed_height - current_height), 0.006), footprint_z * 0.76)
		preview_root.add_child(_mesh_node("RaiseGhost", ghost_mesh, _material(color), Vector3.UP * (step * (float(current_height) + float(proposed_height - current_height) * 0.5))))
	else:
		var arrow_mesh := BoxMesh.new()
		arrow_mesh.size = Vector3(footprint_x * 0.10, maxf(step * 0.70, 0.02), footprint_z * 0.10)
		preview_root.add_child(_mesh_node("LowerArrow", arrow_mesh, _material(color), Vector3.UP * (step * float(current_height) - step * 0.35)))
	_preview_nodes.append(preview_root)
	_last_preview_identity = identity
	return {"ok": true, "preview_id": preview_id, "node_count": _preview_nodes.size()}

func clear_height_preview() -> void:
	for node in _preview_nodes:
		if node != null and is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	_preview_nodes.clear()
	_last_preview_identity = &""
func set_focus_cell(cell: Vector2i, camera: Camera3D) -> void:
	_focus_cell = cell
	_focus_camera = weakref(camera) if camera != null else null
	_refresh_height_label()
	refresh_occlusion(camera)

func _refresh_height_label() -> void:
	var feedback_root := get_node_or_null(NodePath("TerrainFeedbackRoot")) as Node3D
	if feedback_root == null:
		return
	var prior := feedback_root.get_node_or_null(NodePath("HeightLabel"))
	if prior != null:
		feedback_root.remove_child(prior)
		prior.queue_free()
	if not _in_bounds(_focus_cell) or not _cell_states.has(_focus_cell):
		return
	var label := Label3D.new()
	label.name = "HeightLabel"
	label.text = "H%d" % int((_cell_states[_focus_cell] as Dictionary).get("height", 0))
	label.modulate = _profile.get_terrain_feedback_color(&"label")
	label.font_size = 28
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	feedback_root.add_child(label)
	_sync_height_label_position()

func _sync_height_label_position() -> void:
	if not _in_bounds(_focus_cell):
		return
	var label := get_node_or_null(NodePath("TerrainFeedbackRoot/HeightLabel")) as Label3D
	if label != null:
		label.global_position = get_surface_world_position(_focus_cell) + Vector3.UP * 0.12

func refresh_occlusion(camera: Camera3D) -> void:
	_occlusion_refresh_generation += 1
	var next: Array[Vector2i] = []
	var target := get_surface_world_position(_focus_cell)
	if camera != null and is_instance_valid(camera) and _in_bounds(_focus_cell):
		for cell in _cell_roots:
			if cell == _focus_cell or get_visual_height_world(cell) <= 0.0:
				continue
			var body := (_cell_roots[cell] as Node3D).get_node_or_null(NodePath("Body")) as MeshInstance3D
			if body != null and (body.global_transform * body.get_aabb()).intersects_segment(camera.global_position, target):
				next.append(cell)
	_apply_cutaway_cells(next)

func _apply_cutaway_cells(next: Array[Vector2i]) -> void:
	for cell in _cutaway_cells:
		if not cell in next:
			_set_cell_cutaway(cell, false)
	for cell in next:
		if not cell in _cutaway_cells:
			_set_cell_cutaway(cell, true)
	_cutaway_cells = next.duplicate()

func _set_cell_cutaway(cell: Vector2i, enabled: bool) -> void:
	var root := _cell_roots.get(cell, null) as Node3D
	if root == null:
		return
	var body := root.get_node_or_null(NodePath("Body")) as MeshInstance3D
	if body == null:
		return
	var state := _cell_states.get(cell, {}) as Dictionary
	if enabled:
		var cutaway := _get_cutaway_material()
		if cutaway != null:
			body.material_override = cutaway
			body.visible = true
			state["cutaway_uses_alpha_scissor"] = true
			state["cutaway_body_hide_fallback"] = false
		else:
			body.visible = false
			state["cutaway_uses_alpha_scissor"] = false
			state["cutaway_body_hide_fallback"] = true
	else:
		body.material_override = _material(_profile.get_terrain_body_color())
		body.visible = true
		state["cutaway_uses_alpha_scissor"] = false
		state["cutaway_body_hide_fallback"] = false
	_cell_states[cell] = state

func clear_focus() -> void:
	_focus_cell = Vector2i(-1, -1)
	_focus_camera = null
	_apply_cutaway_cells([])
	_refresh_height_label()

func get_cutaway_cells() -> Array[Vector2i]: return _cutaway_cells.duplicate()
func reset_for_stage() -> void:
	if _active_batch_tween != null and _active_batch_tween.is_valid():
		_active_batch_tween.kill()
	_active_batch_tween = null
	_feedback_generation += 1
	_active_batch_cells.clear()
	_last_batch_cells.clear()
	_last_batch_tracks.clear()
	_last_batch_start_frame = -1
	_last_snapshot_revision_by_cell.clear()
	_last_snapshot_cells.clear()
	_reported_issue_keys.clear()
	_process_emissions_by_generation.clear()
	_endpoint_emissions_by_generation.clear()
	set_process(false)
	clear_height_preview()
	for root_name in ["TerrainVisualRoot", "SurfaceAnchorRoot", "TerrainPreviewRoot", "TerrainFeedbackRoot"]:
		var root_node := get_node_or_null(NodePath(root_name))
		if root_node != null:
			_clear_children(root_node)
	_cell_roots.clear()
	_surface_anchors.clear()
	_cell_states.clear()
	_cutaway_cells.clear()
	_focus_cell = Vector2i(-1, -1)
	_focus_camera = null
	_occlusion_refresh_generation = 0
	_cutaway_material = null
func get_debug_snapshot() -> Dictionary:
	return {"column_count": get_column_count(), "surface_anchor_count": get_surface_anchor_count(), "last_batch_cells": _last_batch_cells.duplicate(), "last_batch_start_frame": _last_batch_start_frame, "last_batch_generation": _last_batch_generation, "active_tweens": get_active_tween_count(), "last_snapshot_revision_by_cell": _last_snapshot_revision_by_cell.duplicate(true), "last_batch_tracks": _last_batch_tracks.duplicate(true), "endpoint_emissions": _endpoint_emissions, "ignored_batch_completions": _ignored_batch_completions, "process_emissions_by_generation": _process_emissions_by_generation.duplicate(true), "endpoint_emissions_by_generation": _endpoint_emissions_by_generation.duplicate(true), "occlusion_refresh_generation": _occlusion_refresh_generation, "reported_issue_count": _reported_issue_keys.size(), "reported_issue_keys": _reported_issue_keys.duplicate(true), "preview_node_count": _preview_nodes.size(), "focus_cleared": _focus_cell == Vector2i(-1, -1) and _focus_camera == null, "anchor_cache_cleared": _last_snapshot_cells.is_empty()}
