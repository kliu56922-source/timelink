extends Node3D
class_name TacticalMovementPresenter

## Phase 26E-R1 Task 5: Unified five-lane semantic selector.
## Phase 27D-R3: attack-target semantic markers — legal targets use orange-red,
## illegal targets are dimmed, and boss_core attack uses red-gold (#FFD700) highlight.
## Pure view — stores no card, field, OD, Depth, action, or lane authority.
## Serves: manual summon selection, normal move, OD core redeploy.

signal lane_selected(lane_index: int)
signal cell_selected(cell: Vector2i)
signal cell_hover_changed(cell: Vector2i, hovered: bool)
signal presentation_finished

# ── Semantic lane style constants ──
const COLOR_CYAN := Color(0.3, 0.85, 0.85, 0.75)       # legal selectable
const COLOR_GRAY := Color(0.35, 0.35, 0.35, 0.55)       # occupied, non-selectable
const COLOR_GOLD := Color(1.0, 0.75, 0.15, 0.80)        # source / selected monster
const COLOR_PURPLE := Color(0.65, 0.25, 1.0, 0.75)      # legal OD redeploy target
const COLOR_ORANGE_SWORD := Color(1.0, 0.45, 0.05, 0.90) # same-lane Boss info (accent only)
const COLOR_RED_SHIELD := Color(0.9, 0.15, 0.15, 0.85)   # adjacent Guard risk (accent only)
const MARKER_RING_RADIUS: float = 0.28
const MARKER_RING_HEIGHT: float = 0.02
const MARKER_Y_OFFSET: float = 0.03
const COL_RADIUS: float = 0.35
const COL_HEIGHT: float = 0.18
const HologramPawnClass := preload("res://scenes/presentation/monster_summon_hologram_pawn.gd")

var _anchor_resolver: Callable
var _collision_layer: int = 0
var _active := false
var _lane_markers: Array[Node3D] = []
# Phase 27A: cell-based markers
var _cell_resolver: Callable
# Phase 27I-R0-R4: 棋子选择专用 cell resolver（普通 5×5 格复用 cell resolver；
# 我方虚拟核心格映射到玩家核心表现节点）。只在棋子选择渲染时使用。
var _piece_cell_resolver: Callable
var _cell_markers: Array[Node3D] = []
var _tween: Tween = null
var _intent_tween: Tween = null
# Phase 27A-R1: presentation config, split roots, and feedback
var _presentation_profile: RefCounted = null
var _grid_structure_root: Node3D = null
var _interaction_root: Node3D = null
var _feedback_tween: Tween = null
var _committed_path_root: Node3D = null
var _committed_path_tween: Tween = null
var _drag_hover_root: Node3D = null
var _drag_hover_tween: Tween = null


func get_active_tween_count() -> int:
	var count := 0
	for tween in [_tween, _intent_tween, _feedback_tween, _committed_path_tween, _drag_hover_tween]:
		if tween != null and tween.is_valid():
			count += 1
	return count


func configure(anchor_resolver: Callable, collision_layer: int) -> void:
	_anchor_resolver = anchor_resolver
	_collision_layer = collision_layer


## Phase 27A: cell-based resolver (Vector2i → Node3D)
func configure_cell_resolver(cell_resolver: Callable, collision_layer: int) -> void:
	_cell_resolver = cell_resolver
	_collision_layer = collision_layer


## Reposition existing transient views after an authoritative terrain surface move.
## Areas and their signal/collision setup remain intact.
func refresh_surface_positions() -> void:
	_refresh_surface_positions_in(self)


func _refresh_surface_positions_in(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D and child.has_meta("board_cell"):
			var cell: Vector2i = child.get_meta("board_cell") as Vector2i
			var anchor: Node3D = _cell_resolver.call(cell) as Node3D if _cell_resolver.is_valid() else null
			if anchor != null and is_instance_valid(anchor):
				(child as Node3D).position = to_local(_safe_anchor_pos(anchor)) + Vector3.UP * _profile_float(&"get_surface_offset", 0.018)
		_refresh_surface_positions_in(child)


## Phase 27I-R0-R4: 棋子选择专用 cell resolver。
## 普通 5×5 格 → 场景 _get_3d_anchor_for_cell；我方虚拟核心格 → 玩家核心表现节点。
## 未配置时回退到普通 cell resolver。
func configure_piece_cell_resolver(piece_cell_resolver: Callable) -> void:
	_piece_cell_resolver = piece_cell_resolver


func _piece_cell_anchor(cell: Vector2i) -> Node3D:
	if _piece_cell_resolver.is_valid():
		var node := _piece_cell_resolver.call(cell) as Node3D
		if node != null:
			return node
	if _cell_resolver.is_valid():
		return _cell_resolver.call(cell) as Node3D
	return null


## Phase 27A-R1: inject immutable presentation profile
func configure_presentation_profile(profile: RefCounted) -> void:
	_presentation_profile = profile


func _profile_float(method_name: StringName, fallback: float) -> float:
	if _presentation_profile != null and _presentation_profile.has_method(method_name):
		return float(_presentation_profile.call(method_name))
	return fallback


func _profile_color(method_name: StringName, fallback: Color) -> Color:
	if _presentation_profile != null and _presentation_profile.has_method(method_name):
		return _presentation_profile.call(method_name) as Color
	return fallback


func _cell_axis_local(cell: Vector2i, step: Vector2i, fallback: Vector3) -> Vector3:
	if not _cell_resolver.is_valid():
		return fallback
	var current := _cell_resolver.call(cell) as Node3D
	if current == null:
		return fallback
	var current_local := to_local(_safe_anchor_pos(current))
	var samples: Array[Vector3] = []
	var next_cell := cell + step
	if next_cell.x >= 0 and next_cell.x < 5 and next_cell.y >= 0 and next_cell.y < 5:
		var next_anchor := _cell_resolver.call(next_cell) as Node3D
		if next_anchor != null:
			var next_delta := to_local(_safe_anchor_pos(next_anchor)) - current_local
			next_delta.y = 0.0
			if next_delta.length_squared() > 0.0001:
				samples.append(next_delta)
	var previous_cell := cell - step
	if previous_cell.x >= 0 and previous_cell.x < 5 and previous_cell.y >= 0 and previous_cell.y < 5:
		var previous_anchor := _cell_resolver.call(previous_cell) as Node3D
		if previous_anchor != null:
			var previous_delta := current_local - to_local(_safe_anchor_pos(previous_anchor))
			previous_delta.y = 0.0
			if previous_delta.length_squared() > 0.0001:
				samples.append(previous_delta)
	if samples.is_empty():
		return fallback
	var direction := Vector3.ZERO
	var average_length := 0.0
	for sample in samples:
		direction += sample.normalized()
		average_length += sample.length()
	if direction.length_squared() <= 0.0001:
		return fallback
	return direction.normalized() * (average_length / float(samples.size()))


func _add_outline_bar(
	parent: Node3D,
	bar_name: String,
	center_offset: Vector3,
	direction: Vector3,
	length: float,
	material: Material
) -> void:
	var line := MeshInstance3D.new()
	line.name = bar_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.012, 0.018)
	line.mesh = mesh
	line.position = center_offset
	var tangent := direction.normalized()
	line.rotation.y = -atan2(tangent.z, tangent.x)
	line.material_override = material
	parent.add_child(line)


## Get world-space position from an anchor node safely.
## Falls back to position when global_position is unavailable (headless / early tree).
func _safe_anchor_pos(anchor: Node3D) -> Vector3:
	if anchor.is_inside_tree():
		return anchor.global_position
	return anchor.position


func show_lane_selection(
	mode: StringName,
	owner_side: StringName,
	from_lane: int,
	legal_lanes: Array[int],
	occupied_lanes: Dictionary,
	info_by_lane: Dictionary = {}
) -> void:
	clear_preview()
	_active = true
	for lane_index in range(5):
		var anchor: Node3D = _anchor_resolver.call(owner_side, "front", lane_index)
		if anchor == null:
			continue
		var selectable: bool = lane_index in legal_lanes
		var is_source: bool = (lane_index == from_lane)
		var is_occupied: bool = occupied_lanes.get(lane_index, false)
		# Determine primary color
		var color: Color = COLOR_GRAY
		if is_source:
			color = COLOR_GOLD
		elif is_occupied:
			color = COLOR_GRAY
			selectable = false
		elif mode == &"redeploy" and selectable:
			color = COLOR_PURPLE
		elif selectable:
			color = COLOR_CYAN
		# Accent overlays (informational only, never change selectable)
		var accent_color: Color = Color(0, 0, 0, 0)
		if info_by_lane.has(lane_index):
			var info: Dictionary = info_by_lane[lane_index]
			if bool(info.get("boss_present", false)):
				accent_color = COLOR_ORANGE_SWORD
			elif bool(info.get("guard_risk", false)):
				accent_color = COLOR_RED_SHIELD
		var marker := _create_lane_marker(
			_safe_anchor_pos(anchor), lane_index, owner_side, mode, selectable, color, accent_color
		)
		add_child(marker)
		_lane_markers.append(marker)


## Backward-compat: old Task 4 summon-only API delegates to show_lane_selection
func show_legal_lanes(owner_side: StringName, from_lane: int, legal_lanes: Array[int]) -> void:
	var occupied: Dictionary = {}
	for i in range(5):
		if not i in legal_lanes:
			occupied[i] = true
	show_lane_selection(&"summon", owner_side, from_lane, legal_lanes, occupied, {})


func clear_preview() -> void:
	_active = false
	clear_drag_hover()
	_clear_committed_path()
	_kill_tween()
	_kill_intent_tween()
	_kill_feedback_tween()
	var lane_to_free := _lane_markers.duplicate()
	_lane_markers.clear()
	for m in lane_to_free:
		if is_instance_valid(m):
			if m.get_parent() == self:
				remove_child(m)
			m.queue_free()
	var cell_to_free := _cell_markers.duplicate()
	_cell_markers.clear()
	for m in cell_to_free:
		if is_instance_valid(m):
			if m.get_parent() == self:
				remove_child(m)
			m.queue_free()
	if _grid_structure_root != null and is_instance_valid(_grid_structure_root):
		if _grid_structure_root.get_parent() == self:
			remove_child(_grid_structure_root)
		_grid_structure_root.queue_free()
	if _interaction_root != null and is_instance_valid(_interaction_root):
		if _interaction_root.get_parent() == self:
			remove_child(_interaction_root)
		_interaction_root.queue_free()
	_grid_structure_root = null
	_interaction_root = null


func play_move(token: Node3D, from_transform: Transform3D, to_transform: Transform3D, duration: float = 0.42) -> void:
	if token == null or not is_instance_valid(token):
		presentation_finished.emit()
		return
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(token, "transform", to_transform, duration)
	_tween.tween_callback(func(): presentation_finished.emit())


## Phase 27K-R1-B: consume an already-authoritative path; never pathfind here.
func play_committed_path(path_cells: Array[Vector2i], final_cell: Vector2i, duration: float) -> void:
	_clear_committed_path()
	var committed_cells: Array[Vector2i] = path_cells.duplicate()
	if committed_cells.is_empty() and final_cell != Vector2i(-1, -1):
		committed_cells.append(final_cell)
	var root_node := Node3D.new()
	root_node.name = "CommittedPathRoot"
	root_node.set_meta("path_cells", committed_cells.duplicate())
	root_node.set_meta("final_cell", final_cell)
	add_child(root_node)
	_committed_path_root = root_node
	var marker_count := 0
	for index in range(committed_cells.size()):
		var cell := committed_cells[index]
		var anchor: Node3D = null
		if _cell_resolver.is_valid():
			anchor = _cell_resolver.call(cell) as Node3D
		if anchor == null:
			continue
		var marker := MeshInstance3D.new()
		marker.name = "CommittedPathStep%d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.16 if cell != final_cell else 0.24
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.018
		marker.mesh = mesh
		marker.position = to_local(_safe_anchor_pos(anchor)) + Vector3(0, 0.045, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.9, 1.0, 0.78) if cell != final_cell else Color(1.0, 0.72, 0.18, 0.92)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.5
		marker.material_override = mat
		root_node.add_child(marker)
		marker_count += 1
	root_node.set_meta("marker_count", marker_count)
	_committed_path_tween = create_tween()
	_committed_path_tween.tween_interval(maxf(0.02, duration))
	_committed_path_tween.tween_callback(_clear_committed_path)


func _clear_committed_path() -> void:
	if _committed_path_tween != null and _committed_path_tween.is_valid():
		_committed_path_tween.kill()
	_committed_path_tween = null
	if _committed_path_root != null and is_instance_valid(_committed_path_root):
		if _committed_path_root.get_parent() == self:
			remove_child(_committed_path_root)
		_committed_path_root.queue_free()
	_committed_path_root = null


func play_boss_intent(owner_side: StringName, from_lane: int, to_lane: int) -> void:
	clear_preview()
	_active = true
	var anchor: Node3D = _anchor_resolver.call(owner_side, "front", to_lane)
	if anchor == null:
		return
	var marker := _create_simple_marker(_safe_anchor_pos(anchor), Color(1.0, 0.3, 0.1, 0.8))
	add_child(marker)
	_lane_markers.append(marker)
	_kill_intent_tween()
	_intent_tween = create_tween()
	_intent_tween.tween_interval(1.5)
	_intent_tween.tween_callback(func(): clear_preview())


func cancel() -> void:
	var was_active := _active
	clear_preview()
	if was_active:
		presentation_finished.emit()


func _create_lane_marker(
	pos: Vector3,
	lane_index: int,
	owner_side: StringName,
	mode: StringName,
	selectable: bool,
	color: Color,
	accent_color: Color = Color(0, 0, 0, 0)
) -> Node3D:
	var area := Area3D.new()
	area.collision_layer = _collision_layer
	area.collision_mask = 0
	area.set_meta("target_kind", &"tactical_lane")
	area.set_meta("selection_mode", mode)
	area.set_meta("lane_index", lane_index)
	area.set_meta("owner_side", owner_side)
	area.set_meta("selectable", selectable)
	area.position = pos
	if selectable:
		area.input_event.connect(_on_lane_marker_clicked.bind(lane_index))
	# Main ring
	var ring := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = MARKER_RING_RADIUS
	cylinder.bottom_radius = MARKER_RING_RADIUS
	cylinder.height = MARKER_RING_HEIGHT
	ring.mesh = cylinder
	ring.position = Vector3(0, MARKER_Y_OFFSET, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	area.add_child(ring)
	# Accent ring
	if accent_color.a > 0.01:
		var accent_ring := MeshInstance3D.new()
		var accent_cyl := CylinderMesh.new()
		accent_cyl.top_radius = MARKER_RING_RADIUS * 0.55
		accent_cyl.bottom_radius = MARKER_RING_RADIUS * 0.55
		accent_cyl.height = MARKER_RING_HEIGHT
		accent_ring.mesh = accent_cyl
		accent_ring.position = Vector3(0, MARKER_Y_OFFSET + 0.015, 0)
		var accent_mat := StandardMaterial3D.new()
		accent_mat.albedo_color = accent_color
		accent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		accent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		accent_mat.emission_enabled = true
		accent_mat.emission = accent_color
		accent_mat.emission_energy_multiplier = 0.6
		accent_ring.material_override = accent_mat
		area.add_child(accent_ring)
	# Collision shape
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = COL_RADIUS
	shape.height = COL_HEIGHT
	col.shape = shape
	area.add_child(col)
	return area


func _on_lane_marker_clicked(event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, lane_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	lane_selected.emit(lane_index)


# ── Phase 27A: Cell-based selection ──

func show_cell_selection(
	mode: StringName,
	owner_side: StringName,
	from_cell: Vector2i,
	legal_cells: Array[Vector2i],
	occupied_cells: Dictionary,
	info_by_cell: Dictionary = {}
) -> void:
	clear_preview()
	_active = true
	_grid_structure_root = Node3D.new()
	_grid_structure_root.name = "GridStructureRoot"
	add_child(_grid_structure_root)
	_interaction_root = Node3D.new()
	_interaction_root.name = "InteractionRoot"
	add_child(_interaction_root)
	for rank in range(5):
		for column in range(5):
			var cell := Vector2i(column, rank)
			var anchor: Node3D = null
			if _cell_resolver.is_valid():
				anchor = _cell_resolver.call(cell) as Node3D
			if anchor == null:
				continue
			_grid_structure_root.add_child(_create_cell_outline(cell, _safe_anchor_pos(anchor)))
	for cell in legal_cells:
		if occupied_cells.has(cell):
			continue
		var anchor: Node3D = null
		if _cell_resolver.is_valid():
			anchor = _cell_resolver.call(cell) as Node3D
		if anchor == null:
			continue
		var cell_info: Dictionary = info_by_cell.get(cell, {})
		_interaction_root.add_child(_create_legal_cell_marker(cell, _safe_anchor_pos(anchor), mode, owner_side, cell_info))


# ── Phase 27I-R0: 棋子选择只读渲染 ──
# 只消费 BattleSystem 查询结果；Presenter 不计算合法性/费用/OD/Depth。

func show_piece_selection(
	purpose: StringName,
	action_id: StringName,
	from_cell: Vector2i,
	anchor_cells: Array[Vector2i] = [],
	base_cells: Array[Vector2i] = [],
	enhanced_cells: Array[Vector2i] = [],
	illegal_reasons: Dictionary = {}
) -> void:
	clear_preview()
	_active = true
	_grid_structure_root = Node3D.new()
	_grid_structure_root.name = "GridStructureRoot"
	add_child(_grid_structure_root)
	_interaction_root = Node3D.new()
	_interaction_root.name = "InteractionRoot"
	add_child(_interaction_root)
	for rank in range(5):
		for column in range(5):
			var cell := Vector2i(column, rank)
			var anchor_node: Node3D = null
			if _cell_resolver.is_valid():
				anchor_node = _cell_resolver.call(cell) as Node3D
			if anchor_node == null:
				continue
			_grid_structure_root.add_child(_create_cell_outline(cell, _safe_anchor_pos(anchor_node)))
	var seen := {}
	_add_piece_cells(anchor_cells, &"anchor", seen, action_id)
	_add_piece_cells(base_cells, &"base", seen, action_id)
	_add_piece_cells(enhanced_cells, &"enhanced", seen, action_id)
	for cell in illegal_reasons:
		var c: Vector2i = cell
		if not seen.has(c):
			_add_piece_cells([c], &"illegal", seen, action_id)


func _add_piece_cells(cells: Array, kind: StringName, seen: Dictionary, action_id: StringName = &"") -> void:
	for raw_cell in cells:
		var cell := raw_cell as Vector2i
		if cell == Vector2i(-1, -1) or seen.has(cell):
			continue
		seen[cell] = true
		var anchor_node := _piece_cell_anchor(cell)
		if anchor_node == null:
			continue
		# Phase 27I-R0-R3: 合法棋子格使用可交互 Area3D 标记（可被中央射线点击确认）；
		# illegal 仍为只读（selectable=false），不进入确认。
		var marker := _create_piece_cell_marker(cell, _safe_anchor_pos(anchor_node), kind, action_id)
		_interaction_root.add_child(marker)


## Phase 27I-R0-R3: 可交互棋子格标记。
## 合法 anchor/base/enhanced 具备完整语义元数据并可被 BattleScene 射线点击；
## illegal 只读（selectable=false，不连接点击信号），仅作视觉提示。
## 所有合法格仍只来自 BattleSystem 查询结果，Presenter 不计算合法性/费用/OD/Depth。
func _create_piece_cell_marker(cell: Vector2i, world_pos: Vector3, kind: StringName, action_id: StringName) -> Area3D:
	var selectable: bool = kind != &"illegal"
	var area := Area3D.new()
	area.name = "Piece_%s_%d_%d" % [kind, cell.x, cell.y]
	area.collision_layer = _collision_layer
	area.collision_mask = 0
	area.input_ray_pickable = true
	area.monitoring = true
	area.monitorable = true
	area.set_meta("target_kind", &"tactical_cell")
	area.set_meta("selection_mode", &"piece_anchor")
	area.set_meta("board_cell", cell)
	area.set_meta("piece_kind", kind)
	area.set_meta("piece_action_id", action_id)
	area.set_meta("owner_side", &"player")
	area.set_meta("selectable", selectable)
	area.position = to_local(world_pos) + Vector3.UP * _profile_float(&"get_surface_offset", 0.018)
	if selectable:
		area.input_event.connect(_on_cell_marker_clicked.bind(cell))
	var color := _piece_kind_color(kind)
	var ring := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = MARKER_RING_RADIUS
	cylinder.bottom_radius = MARKER_RING_RADIUS
	cylinder.height = MARKER_RING_HEIGHT
	ring.mesh = cylinder
	ring.position = Vector3(0, MARKER_Y_OFFSET, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	area.add_child(ring)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = COL_RADIUS
	shape.height = COL_HEIGHT
	col.shape = shape
	area.add_child(col)
	return area


func _piece_kind_color(kind: StringName) -> Color:
	match kind:
		&"anchor": return Color(1.0, 0.75, 0.15, 0.80)     # gold
		&"base": return Color(0.26, 0.92, 0.96, 0.75)       # cyan
		&"enhanced": return Color(0.65, 0.25, 1.0, 0.78)    # violet
		&"illegal": return Color(0.45, 0.30, 0.32, 0.55)    # dim red-gray
	return Color(0.3, 0.85, 0.85, 0.7)


# ── Phase 27A-R1: 25-cell structural outlines (no collision, no Area3D) ──

func _create_cell_outline(cell: Vector2i, world_pos: Vector3) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "Cell_%d_%d" % [cell.x, cell.y]
	root_node.set_meta("board_cell", cell)
	root_node.position = to_local(world_pos) + Vector3.UP * _profile_float(&"get_surface_offset", 0.018)
	var column_axis := _cell_axis_local(cell, Vector2i(1, 0), Vector3.RIGHT * 1.20)
	var rank_axis := _cell_axis_local(cell, Vector2i(0, 1), Vector3.BACK * 1.20)
	var inset_ratio := _profile_float(&"get_cell_inset_ratio", 0.76)
	var column_span := column_axis.length() * inset_ratio
	var rank_span := rank_axis.length() * inset_ratio
	root_node.set_meta("outline_column_span", column_span)
	root_node.set_meta("outline_rank_span", rank_span)
	var color := _profile_color(&"get_grid_line_color", Color("#39D9FF"))
	color.a = _profile_float(&"get_grid_line_alpha", 0.26)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 0.65
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var column_direction := column_axis.normalized()
	var rank_direction := rank_axis.normalized()
	_add_outline_bar(root_node, "ColumnNear", -rank_direction * rank_span * 0.5, column_direction, column_span, mat)
	_add_outline_bar(root_node, "ColumnFar", rank_direction * rank_span * 0.5, column_direction, column_span, mat)
	_add_outline_bar(root_node, "RankLeft", -column_direction * column_span * 0.5, rank_direction, rank_span, mat)
	_add_outline_bar(root_node, "RankRight", column_direction * column_span * 0.5, rank_direction, rank_span, mat)
	return root_node


# ── Phase 27A-R1: legal-cell Area3D with cyan circle marker ──

func _create_legal_cell_marker(cell: Vector2i, world_pos: Vector3, mode: StringName, owner_side: StringName, cell_info: Dictionary = {}) -> Area3D:
	var area := Area3D.new()
	area.name = "Cell_%d_%d" % [cell.x, cell.y]
	area.collision_layer = _collision_layer
	area.collision_mask = 0
	area.input_ray_pickable = true
	area.monitoring = true
	area.monitorable = true
	area.set_meta("target_kind", &"tactical_cell")
	area.set_meta("selection_mode", mode)
	area.set_meta("board_cell", cell)
	area.set_meta("owner_side", owner_side)
	area.set_meta("selectable", true)
	if cell_info.has("is_target") and cell_info.is_target:
		area.set_meta("is_attack_target", true)
		if cell_info.has("target_card"):
			area.set_meta("target_card", cell_info.target_card)
	area.position = to_local(world_pos) + Vector3.UP * _profile_float(&"get_surface_offset", 0.018)
	area.input_event.connect(_on_cell_marker_clicked.bind(cell))
	area.mouse_entered.connect(_on_legal_cell_hovered.bind(area, true))
	area.mouse_exited.connect(_on_legal_cell_hovered.bind(area, false))
	# Phase 27B: color by mode
	var marker_color: Color
	match mode:
		&"attack":
			marker_color = Color("#FF6622")  # orange-red for attack range
		&"move", &"redeploy":
			marker_color = Color("#42E9F5")  # cyan for move
		_:
			marker_color = _profile_color(&"get_summon_marker_color", Color("#42E9F5"))
	# If this cell has an attack target, use stronger red
	if cell_info.has("is_target") and cell_info.is_target:
		marker_color = Color("#FF3311")  # bright red for legal attack targets
	var radius := _profile_float(&"get_summon_radius_ratio", 0.21)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = radius * 1.18
	ring_mesh.bottom_radius = ring_mesh.top_radius
	ring_mesh.height = MARKER_RING_HEIGHT
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, _profile_float(&"get_summon_ring_alpha", 0.86))
	ring_mat.emission_enabled = true
	ring_mat.emission = marker_color
	ring_mat.emission_energy_multiplier = 0.75
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	area.add_child(ring)
	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = radius * 0.82
	fill_mesh.bottom_radius = fill_mesh.top_radius
	fill_mesh.height = MARKER_RING_HEIGHT
	fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, _profile_float(&"get_summon_fill_alpha", 0.30))
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.material_override = fill_mat
	area.add_child(fill)
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = clampf(radius * 1.30, 0.18, 0.34)
	shape.height = COL_HEIGHT
	shape_node.shape = shape
	area.add_child(shape_node)
	return area


func _on_legal_cell_hovered(area: Area3D, hovered: bool) -> void:
	if not is_instance_valid(area):
		return
	var target := Vector3.ONE * (_profile_float(&"get_hover_scale", 1.12) if hovered else 1.0)
	area.scale = target
	var cell: Variant = area.get_meta("board_cell", Vector2i(-1, -1))
	if cell is Vector2i:
		cell_hover_changed.emit(cell, hovered)


## Read-only monster drag hover. The supplied status is authoritative; this
## presenter only maps it to a single marker and optional placement ghost.
func set_drag_hover(cell: Vector2i, status: Dictionary, reduced_motion: bool, visual_state: StringName = &"hover", card: CardData = null) -> void:
	clear_drag_hover()
	var anchor: Node3D = _cell_resolver.call(cell) as Node3D if _cell_resolver.is_valid() else null
	if anchor == null:
		return
	var valid := bool(status.get("ok", false))
	_drag_hover_root = _create_drag_hover_marker(cell, _safe_anchor_pos(anchor), valid)
	_drag_hover_root.set_meta("visual_state", visual_state)
	add_child(_drag_hover_root)
	if valid:
		_drag_hover_root.add_child(_create_drag_summon_ghost(card, visual_state, reduced_motion))
	if not reduced_motion:
		_drag_hover_tween = create_tween()
		_drag_hover_tween.tween_property(_drag_hover_root, "scale", Vector3.ONE * 1.06, 0.08)


func clear_drag_hover() -> void:
	if _drag_hover_tween != null and _drag_hover_tween.is_valid():
		_drag_hover_tween.kill()
	_drag_hover_tween = null
	if _drag_hover_root != null and is_instance_valid(_drag_hover_root):
		if _drag_hover_root.get_parent() == self:
			remove_child(_drag_hover_root)
		_drag_hover_root.queue_free()
	_drag_hover_root = null


func get_drag_debug_snapshot() -> Dictionary:
	var has_root := _drag_hover_root != null and is_instance_valid(_drag_hover_root)
	var ghost_count := 0
	var ghost_kind: StringName = &""
	var ghost_state: StringName = &""
	var ghost_mesh_count := 0
	var pawn_active_tweens := 0
	var pawn_motion_processing := false
	var cell := Vector2i(-1, -1)
	if has_root:
		cell = _drag_hover_root.get_meta("board_cell", Vector2i(-1, -1)) as Vector2i
		ghost_state = _drag_hover_root.get_meta("visual_state", &"fallback") as StringName
		var ghost := _drag_hover_root.get_node_or_null(NodePath("SummonGhost")) as Node3D
		if ghost != null:
			ghost_count = 1
			ghost_kind = &"hologram_pawn"
			ghost_mesh_count = ghost.find_children("*", "MeshInstance3D", true, false).size()
			var pawn := ghost.get_node_or_null(NodePath("HologramPawn"))
			if pawn != null and pawn.has_method("get_debug_snapshot"):
				var pawn_snapshot: Dictionary = pawn.call("get_debug_snapshot")
				ghost_state = pawn_snapshot.get("visual_state", ghost_state) as StringName
				pawn_active_tweens = int(pawn_snapshot.get("active_tweens", 0))
				pawn_motion_processing = bool(pawn_snapshot.get("motion_processing", false))
	return {
		"cell": cell,
		"ghost_count": ghost_count,
		"ghost_kind": ghost_kind,
		"ghost_state": ghost_state,
		"ghost_mesh_count": ghost_mesh_count,
		"node_count": 1 if has_root else 0,
		"active_tweens": 1 if _drag_hover_tween != null and _drag_hover_tween.is_valid() else 0,
		"pawn_active_tweens": pawn_active_tweens,
		"pawn_motion_processing": pawn_motion_processing,
	}


func _create_drag_hover_marker(cell: Vector2i, world_pos: Vector3, valid: bool) -> Node3D:
	var marker := Node3D.new()
	marker.name = "DragHover_%d_%d" % [cell.x, cell.y]
	marker.position = to_local(world_pos) + Vector3.UP * _profile_float(&"get_surface_offset", 0.018)
	marker.set_meta("board_cell", cell)
	marker.set_meta("valid", valid)
	marker.set_meta("presentation_only", true)
	var ring := MeshInstance3D.new()
	ring.name = "HoverRing"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.30
	mesh.bottom_radius = 0.30
	mesh.height = 0.022
	ring.mesh = mesh
	var color := Color("#42E9F5") if valid else Color("#E34A4A")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.82)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.75
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	marker.add_child(ring)
	return marker


func _create_drag_summon_ghost(card: CardData, visual_state: StringName, reduced_motion: bool) -> Node3D:
	var ghost := Node3D.new()
	ghost.name = "SummonGhost"
	ghost.set_meta("presentation_only", true)
	ghost.position = Vector3.UP * 0.04
	var pawn := HologramPawnClass.new()
	pawn.name = "HologramPawn"
	pawn.configure(card, visual_state, reduced_motion)
	ghost.add_child(pawn)
	return ghost


# ── Phase 27A-R1: confirm / reject feedback ──

func play_cell_confirm(cell: Vector2i) -> void:
	if _interaction_root == null:
		return
	var marker := _interaction_root.get_node_or_null("Cell_%d_%d" % [cell.x, cell.y]) as Node3D
	if marker == null:
		return
	_kill_feedback_tween()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(marker, "scale", Vector3.ONE * 1.24, _profile_float(&"get_confirm_flash_seconds", 0.08))


func play_cell_reject(cell: Vector2i) -> void:
	if _interaction_root == null:
		return
	var marker := _interaction_root.get_node_or_null("Cell_%d_%d" % [cell.x, cell.y]) as Node3D
	if marker == null:
		return
	_kill_feedback_tween()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(marker, "scale", Vector3.ONE * 0.92, _profile_float(&"get_reject_pulse_seconds", 0.14) * 0.5)
	_feedback_tween.tween_property(marker, "scale", Vector3.ONE, _profile_float(&"get_reject_pulse_seconds", 0.14) * 0.5)


func _kill_feedback_tween() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null


# ── LEGACY (Phase 27A): 保留用于 backward compat ──

func _create_cell_marker(
	cell: Vector2i,
	pos: Vector3,
	mode: StringName,
	owner_side: StringName,
	selectable: bool,
	color: Color
) -> Node3D:
	var area := Area3D.new()
	area.collision_layer = _collision_layer
	area.collision_mask = 0
	area.set_meta("target_kind", &"tactical_cell")
	area.set_meta("selection_mode", mode)
	area.set_meta("board_cell", cell)
	area.set_meta("owner_side", owner_side)
	area.set_meta("selectable", selectable)
	area.position = pos
	if selectable:
		area.input_event.connect(_on_cell_marker_clicked.bind(cell))
	# Visual: cylinder ring for summon/move, box for attack, ring for source
	if mode == &"attack":
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.5, 0.04, 0.5)
		box.mesh = box_mesh
		box.position = Vector3(0, MARKER_Y_OFFSET, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		box.material_override = mat
		area.add_child(box)
	else:
		var ring := MeshInstance3D.new()
		if mode == &"move":
			var tri_mesh := CylinderMesh.new()
			tri_mesh.top_radius = MARKER_RING_RADIUS
			tri_mesh.bottom_radius = MARKER_RING_RADIUS
			tri_mesh.height = MARKER_RING_HEIGHT
			tri_mesh.radial_segments = 3
			ring.mesh = tri_mesh
		else:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = MARKER_RING_RADIUS
			cylinder.bottom_radius = MARKER_RING_RADIUS
			cylinder.height = MARKER_RING_HEIGHT
			ring.mesh = cylinder
		ring.position = Vector3(0, MARKER_Y_OFFSET, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		area.add_child(ring)
	# Collision shape
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = COL_RADIUS
	shape.height = COL_HEIGHT
	col.shape = shape
	area.add_child(col)
	return area


func _on_cell_marker_clicked(event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, cell: Vector2i) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
		# [CELL_SELECTION_STATE] diagnostic
		print("[CELL_SELECTION_STATE] marker_clicked cell=%s" % str(cell))
	cell_selected.emit(cell)


## Minimal marker without metadata — only for transient read-only visuals (e.g. Boss intent pulse)
func _create_simple_marker(pos: Vector3, color: Color) -> Node3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 0
	area.position = pos
	var ring := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = MARKER_RING_RADIUS
	cylinder.bottom_radius = MARKER_RING_RADIUS
	cylinder.height = MARKER_RING_HEIGHT
	ring.mesh = cylinder
	ring.position = Vector3(0, MARKER_Y_OFFSET, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	area.add_child(ring)
	return area


func _kill_tween() -> void:
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = null


func _kill_intent_tween() -> void:
	if _intent_tween and is_instance_valid(_intent_tween):
		_intent_tween.kill()
	_intent_tween = null
