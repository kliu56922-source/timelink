extends Node3D
class_name CloudGateBoardRuntime

## Phase 22F-6: CloudGate 棋盘运行时包装 — 轴转置校准
## 结构: CloudGateBoardRuntime → ModelPivot (GLB) + SocketRoot (Marker3D anchors)
##
## 语义约定 (Phase 22F-6 轴转置):
##   World Z  = 棋盘长轴 — 五列横向排列
##   World X  = 玩家/Boss 阵营分区
##   Player   → world +X
##   Boss     → world -X
##   V03 AABB ≈ (5.57, 0.87, 10.0) — Z 为长轴

const GLB_PATH := "res://assets/table/3d/cloudgate_battle_board_v03.glb"
## Phase 23C0: 分排牌区表面高度（从 TSCN 设计值恢复）
## 前排 MONSTER 区表面略高于后排 BUILD/COUNTER 区
## SOCKET_SURFACE_Y 保留兼容旧代码，弃用中
const SOCKET_SURFACE_Y := 0.89
const BOARD_SURFACE_Y_FRONT := 0.48   # 前排牌区实际表面
const BOARD_SURFACE_Y_BACK := 0.42    # 后排牌区实际表面
const CARRIER_TARGET_GAP := 0.015     # Carrier 底面与牌区表面目标间隙
const USE_CLAY_BOARD_MATERIAL := false
const CLAY_BOARD_COLOR := Color(0.42, 0.45, 0.50, 1.0)

## Phase 22F-6: 调试 Socket 锚点显示 — 默认关闭
const DEBUG_SHOW_3D_SLOT_ANCHORS := false

## Phase 22F-5: 仅调试方位标记 — 默认关闭
const DEBUG_SHOW_BOARD_CARDINALS := false
const CARDINAL_LABEL_Y_OFFSET := 0.15

# ── 模型变换（严禁修改）──
const MODEL_PIVOT_YAW_DEGREES := 0.0
const MODEL_PIVOT_SCALE := Vector3(1.0, 1.0, 1.0)
const MODEL_PIVOT_POSITION := Vector3(0.0, 0.0, 0.0)

# ── Debug marker 颜色映射 ──
const SOCKET_COLORS := {
	"P_FRONT": Color(0.16, 0.62, 1.0, 1),
	"P_BACK": Color(0.16, 0.95, 0.56, 1),
	"B_FRONT": Color(1.0, 0.28, 0.08, 1),
	"B_BACK": Color(0.65, 0.14, 0.06, 1),
	"ACTION_SLOT": Color(0.85, 0.85, 0.40, 1),
	"BOSS_CORE": Color(1.0, 0.12, 0.30, 1),
	"PLAYER_DECK": Color(0.16, 0.75, 1.0, 1),
	"PLAYER_GY": Color(0.14, 0.55, 0.70, 1),
	"BOSS_DECK": Color(1.0, 0.40, 0.12, 1),
	"BOSS_GY": Color(0.75, 0.30, 0.10, 1),
	"OD_DOCK": Color(0.75, 0.20, 0.95, 1),
}

var _glb_loaded := false
var _model_pivot: Node3D = null
var _socket_root: Node3D = null
var _glb_instance: Node3D = null


func _ready() -> void:
	_model_pivot = get_node_or_null(NodePath("ModelPivot")) as Node3D
	_socket_root = get_node_or_null(NodePath("SocketRoot")) as Node3D
	_calibrate_socket_surface_height()
	if _model_pivot:
		_apply_model_transform()
		print("[BOARD_CAL] yaw=%.1f scale=%s pos=%s" % [MODEL_PIVOT_YAW_DEGREES, MODEL_PIVOT_SCALE, MODEL_PIVOT_POSITION])


func _calibrate_socket_surface_height() -> void:
	if not _socket_root:
		return
	var calibrated := 0
	for child in _socket_root.get_children():
		if child is Marker3D:
			var marker := child as Marker3D
			var m_name: String = marker.name
			# Phase 23C0: Use per-zone surface height instead of uniform 0.89
			if m_name.begins_with("P_FRONT") or m_name.begins_with("B_FRONT"):
				marker.position.y = BOARD_SURFACE_Y_FRONT
			elif m_name.begins_with("P_BACK") or m_name.begins_with("B_BACK"):
				marker.position.y = BOARD_SURFACE_Y_BACK
			else:
				# Non-card sockets keep the legacy surface Y
				marker.position.y = SOCKET_SURFACE_Y
			calibrated += 1
	print("[BOARD_CAL] socket_surface_y=%.2f front=%.2f back=%.2f count=%d" % [SOCKET_SURFACE_Y, BOARD_SURFACE_Y_FRONT, BOARD_SURFACE_Y_BACK, calibrated])


func _apply_model_transform() -> void:
	_model_pivot.rotation_degrees.y = MODEL_PIVOT_YAW_DEGREES
	_model_pivot.scale = MODEL_PIVOT_SCALE
	_model_pivot.position = MODEL_PIVOT_POSITION


func load_glb() -> bool:
	if not _model_pivot:
		printerr("[CloudGateBoardRuntime] ModelPivot not found!")
		return false
	if _glb_loaded:
		return true
	if not ResourceLoader.exists(GLB_PATH):
		print("[CloudGateBoardRuntime] GLB not found: %s" % GLB_PATH)
		return false
	var glb_scene := load(GLB_PATH) as PackedScene
	if glb_scene == null:
		print("[CloudGateBoardRuntime] GLB load failed")
		return false
	var instance := glb_scene.instantiate() as Node3D
	if instance == null:
		print("[CloudGateBoardRuntime] GLB instantiate failed")
		return false
	instance.name = "CloudGateBoard"
	_model_pivot.add_child(instance)
	_glb_instance = instance
	_apply_clay_material_override(instance)
	_glb_loaded = true
	print("[BOARD_CAL] loaded=%s" % GLB_PATH)
	_print_calibration_diagnostics()
	_validate_all_sockets()
	if DEBUG_SHOW_BOARD_CARDINALS:
		_add_debug_cardinals()
	if DEBUG_SHOW_3D_SLOT_ANCHORS:
		_add_debug_slot_anchors()
	return true


func _apply_clay_material_override(root: Node) -> void:
	if not USE_CLAY_BOARD_MATERIAL:
		return
	var clay := StandardMaterial3D.new()
	clay.albedo_color = CLAY_BOARD_COLOR
	clay.metallic = 0.05
	clay.roughness = 0.92
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)
	for mesh in meshes:
		mesh.material_override = clay
	print("[BOARD_CAL] clay_material=true meshes=%d" % meshes.size())


## Phase 22F-6: 校准诊断 — 长轴 Z, 阵营 X
func _print_calibration_diagnostics() -> void:
	if not _glb_instance:
		print("[BOARD_CAL] ERROR: no GLB instance loaded")
		return
	var world_aabb := _compute_glb_world_aabb()
	if world_aabb:
		var world_size := world_aabb.size
		print("[BOARD_CAL] size≈(%.4f,%.4f,%.4f)" % [world_size.x, world_size.y, world_size.z])
		print("[BOARD_AXIS] long_axis=Z")
	else:
		print("[BOARD_CAL] world AABB computation failed")
	print("[BOARD_AXIS] factions=X player=+X boss=-X")
	print("[BOARD_CAL] yaw=%.1f" % MODEL_PIVOT_YAW_DEGREES)
	print("[BOARD_CAL] scale=(%.1f,%.1f,%.1f)" % [MODEL_PIVOT_SCALE.x, MODEL_PIVOT_SCALE.y, MODEL_PIVOT_SCALE.z])
	print("[BOARD_CAL] sockets=%d od_dock=%s" % [get_all_socket_markers().size(), get_socket_local_position("OD_DOCK")])


func _compute_glb_local_aabb(root: Node3D) -> AABB:
	if root == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)
	if meshes.is_empty():
		return AABB()
	var merged := meshes[0].get_aabb()
	for i in range(1, meshes.size()):
		merged = merged.merge(meshes[i].get_aabb())
	return merged


func _compute_glb_world_aabb() -> AABB:
	if not _glb_instance:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(_glb_instance, meshes)
	if meshes.is_empty():
		return AABB()
	var first := meshes[0] as MeshInstance3D
	var merged := first.global_transform * first.get_aabb()
	for i in range(1, meshes.size()):
		var mi := meshes[i] as MeshInstance3D
		merged = merged.merge(mi.global_transform * mi.get_aabb())
	return merged


func _collect_mesh_instances(node: Node, out_meshes: Array) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		if is_instance_valid(child):
			_collect_mesh_instances(child, out_meshes)


func is_glb_loaded() -> bool:
	return _glb_loaded


func get_model_yaw() -> float:
	return MODEL_PIVOT_YAW_DEGREES


func get_model_scale() -> Vector3:
	return MODEL_PIVOT_SCALE


func get_model_position() -> Vector3:
	return MODEL_PIVOT_POSITION


func get_glb_instance() -> Node3D:
	return _glb_instance


func get_world_aabb() -> AABB:
	return _compute_glb_world_aabb()


func get_all_socket_markers() -> Array[Marker3D]:
	if not _socket_root:
		return []
	var markers: Array[Marker3D] = []
	for child in _socket_root.get_children():
		if child is Marker3D and is_instance_valid(child):
			markers.append(child as Marker3D)
	return markers


func get_socket_marker(marker_name: String) -> Marker3D:
	if not _socket_root:
		return null
	return _socket_root.get_node_or_null(NodePath(marker_name)) as Marker3D


func get_socket_global_position(marker_name: String) -> Vector3:
	var marker := get_socket_marker(marker_name)
	if marker:
		return marker.global_position
	return Vector3.ZERO


func get_socket_local_position(marker_name: String) -> Vector3:
	var marker := get_socket_marker(marker_name)
	if marker:
		return marker.position
	return Vector3.ZERO


func get_socket_names() -> PackedStringArray:
	var names: PackedStringArray = []
	if not _socket_root:
		return names
	for child in _socket_root.get_children():
		if child is Marker3D and is_instance_valid(child):
			names.append(child.name)
	return names


## Phase 23C0: Get the visual board surface Y for a card zone (front/back).
## This is the actual board surface, not the socket marker Y.
func get_board_surface_y_for_zone(zone: String) -> float:
	if zone == "front":
		return BOARD_SURFACE_Y_FRONT
	return BOARD_SURFACE_Y_BACK


func get_target_carrier_gap() -> float:
	return CARRIER_TARGET_GAP


func print_socket_diagnostics(verbose: bool = true) -> void:
	var markers: Array = get_all_socket_markers()
	print("[BOARD_SOCKETS] source=runtime_scene count=%d" % markers.size())
	if not verbose:
		return
	for m: Marker3D in markers:
		var color_hint := ""
		for prefix in SOCKET_COLORS:
			if m.name.begins_with(prefix):
				color_hint = " " + prefix
				break
		print("[BOARD_SOCKET] %s=(%.2f,%.3f,%.2f)%s" % [m.name, m.position.x, m.position.y, m.position.z, color_hint])


## Phase 22F-6: 验证 27 Socket — Z 五列横向, X 玩家(+X)/Boss(-X) 分区
func _validate_all_sockets() -> void:
	var markers := get_all_socket_markers()
	if markers.is_empty():
		print("[BOARD_SOCKET_VALIDATE] FAIL — no markers found")
		return
	print("[BOARD_SOCKET_VALIDATE] count=%d" % markers.size())

	var world_aabb := _compute_glb_world_aabb()
	if world_aabb:
		print("[BOARD_SOCKET_VALIDATE] model_aabb=X(%.2f..%.2f) Z(%.2f..%.2f)" % [world_aabb.position.x, world_aabb.end.x, world_aabb.position.z, world_aabb.end.z])

	var all_ok := true
	var player_count := 0
	var boss_count := 0
	var od_dock_found := false
	var x_violations := 0
	var z_violations := 0
	var y_violations := 0
	var p_front_z_vals: Array = []
	var p_back_z_vals: Array = []
	var b_front_z_vals: Array = []
	var b_back_z_vals: Array = []
	for m in markers:
		var p := m.position
		var m_name: String = m.name

		# Phase 23C0: Per-zone Y validation
		var expected_y: float = SOCKET_SURFACE_Y
		if m_name.begins_with("P_FRONT") or m_name.begins_with("B_FRONT"):
			expected_y = BOARD_SURFACE_Y_FRONT
		elif m_name.begins_with("P_BACK") or m_name.begins_with("B_BACK"):
			expected_y = BOARD_SURFACE_Y_BACK
		if abs(p.y - expected_y) > 0.02:
			y_violations += 1
			print("[BOARD_SOCKET_VALIDATE] Y_VIOLATION: %s y=%.3f (expected %.2f)" % [m_name, p.y, expected_y])
			all_ok = false

		# Player: +X
		if m_name.begins_with("P_"):
			player_count += 1
			if p.x <= 0.0:
				x_violations += 1
				print("[BOARD_SOCKET_VALIDATE] X_VIOLATION: %s x=%.2f (expected +X player)" % [m_name, p.x])
				all_ok = false
			if m_name.begins_with("P_FRONT"):
				p_front_z_vals.append(p.z)
			elif m_name.begins_with("P_BACK"):
				p_back_z_vals.append(p.z)

		# Boss: -X
		if m_name.begins_with("B_"):
			boss_count += 1
			if p.x >= 0.0:
				x_violations += 1
				print("[BOARD_SOCKET_VALIDATE] X_VIOLATION: %s x=%.2f (expected -X boss)" % [m_name, p.x])
				all_ok = false
			if m_name.begins_with("B_FRONT"):
				b_front_z_vals.append(p.z)
			elif m_name.begins_with("B_BACK"):
				b_back_z_vals.append(p.z)

		if m_name == "OD_DOCK":
			od_dock_found = true
			if p.x <= 0.0:
				print("[BOARD_SOCKET_VALIDATE] OD_DOCK X_VIOLATION: x=%.2f (expected +X player side)" % p.x)
				all_ok = false

		# AABB check — only for battle card sockets (P_/B_), not special sockets
		if world_aabb and (m_name.begins_with("P_") or m_name.begins_with("B_")):
			if p.x < world_aabb.position.x - 0.1 or p.x > world_aabb.end.x + 0.1:
				x_violations += 1
				print("[BOARD_SOCKET_VALIDATE] AABB_X_VIOLATION: %s x=%.2f" % [m_name, p.x])
				all_ok = false
			if p.z < world_aabb.position.z - 1.0 or p.z > world_aabb.end.z + 1.0:
				z_violations += 1
				print("[BOARD_SOCKET_VALIDATE] AABB_Z_VIOLATION: %s z=%.2f" % [m_name, p.z])
				all_ok = false

	# Z increasing check (5 columns along Z)
	if p_front_z_vals.size() == 5:
		if not _check_z_increasing(p_front_z_vals, "P_FRONT"):
			all_ok = false
	if p_back_z_vals.size() == 5:
		if not _check_z_increasing(p_back_z_vals, "P_BACK"):
			all_ok = false
	if b_front_z_vals.size() == 5:
		if not _check_z_increasing(b_front_z_vals, "B_FRONT"):
			all_ok = false
	if b_back_z_vals.size() == 5:
		if not _check_z_increasing(b_back_z_vals, "B_BACK"):
			all_ok = false

	# X row ordering: B_BACK < B_FRONT < 0 < P_FRONT < P_BACK
	var b_back_x := 0.0
	var b_front_x := 0.0
	var p_front_x := 0.0
	var p_back_x := 0.0
	for m in markers:
		var m_name: String = m.name
		match m_name:
			"B_BACK_0":  b_back_x  = m.position.x
			"B_FRONT_0": b_front_x = m.position.x
			"P_FRONT_0": p_front_x = m.position.x
			"P_BACK_0":  p_back_x  = m.position.x
	if b_back_x < b_front_x and b_front_x < 0 and 0 < p_front_x and p_front_x < p_back_x:
		pass  # correct ordering
	else:
		print("[BOARD_SOCKET_VALIDATE] X_ROW_ORDER_VIOLATION: B_BACK(%.2f) < B_FRONT(%.2f) < 0 < P_FRONT(%.2f) < P_BACK(%.2f) FAILED" % [b_back_x, b_front_x, p_front_x, p_back_x])
		all_ok = false

	print("[BOARD_SOCKET_VALIDATE] player_markers=%d boss_markers=%d od_dock=%s" % [player_count, boss_count, od_dock_found])
	print("[BOARD_SOCKET_VALIDATE] violations: Y=%d X=%d Z=%d AABB_X=%d AABB_Z=%d" % [y_violations, x_violations, z_violations, x_violations, z_violations])
	print("[BOARD_SOCKET_VALIDATE] result=%s" % ("PASS" if all_ok else "FAIL"))


## Phase 22F-6: Z 递增检查（五列沿 Z 轴）
func _check_z_increasing(z_vals: Array, row_name: String) -> bool:
	if z_vals.size() < 2:
		return true
	var sorted := z_vals.duplicate()
	sorted.sort()
	for i in z_vals.size():
		if abs(z_vals[i] - sorted[i]) > 0.01:
			print("[BOARD_SOCKET_VALIDATE] Z_ORDER_VIOLATION: %s z_vals=%s (expected increasing)" % [row_name, z_vals])
			return false
	return true


## Phase 22F-6: Debug Socket 锚点可视化（Label3D + 色球）
func _add_debug_slot_anchors() -> void:
	if not _socket_root:
		return
	var markers := get_all_socket_markers()
	if markers.is_empty():
		return
	print("[BOARD_DEBUG_ANCHORS] adding %d markers" % markers.size())
	for m: Marker3D in markers:
		if not is_instance_valid(m):
			continue
		var dc := Color.WHITE
		for prefix in SOCKET_COLORS:
			if m.name.begins_with(prefix):
				dc = SOCKET_COLORS[prefix]
				break
		# Sphere
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mi := MeshInstance3D.new()
		mi.name = "DebugAnchorMesh"
		mi.mesh = sphere
		mi.position = m.position + Vector3(0, 0.05, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = dc
		mat.emission_enabled = true
		mat.emission = dc * 0.3
		mat.emission_energy = 0.6
		mi.material_override = mat
		mi.set_meta("_debug_anchor", true)
		add_child(mi)
		# Label
		var label := Label3D.new()
		label.name = "DebugAnchorLabel"
		label.text = m.name
		label.position = m.position + Vector3(0, 0.18, 0)
		label.modulate = dc
		label.font_size = 10
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.shaded = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_meta("_debug_anchor", true)
		add_child(label)


## Phase 22F-6: 方位标记 — 棋盘四角 + OD_DOCK
func _add_debug_cardinals() -> void:
	if not _socket_root:
		print("[BOARD_CARDINAL_DEBUG] SocketRoot not found")
		return
	var world_aabb := _compute_glb_world_aabb()
	if not world_aabb:
		print("[BOARD_CARDINAL_DEBUG] No world AABB")
		return

	var surf_y := SOCKET_SURFACE_Y + CARDINAL_LABEL_Y_OFFSET
	var margin := 0.35

	# Boss (-X)
	_add_one_cardinal("BOSS\n-X", Vector3(world_aabb.position.x - margin, surf_y, 0.0), Color(1.0, 0.2, 0.15, 1.0))
	# Player (+X)
	_add_one_cardinal("PLAYER\n+X", Vector3(world_aabb.end.x + margin, surf_y, 0.0), Color(0.16, 0.62, 1.0, 1.0))
	# Left (-Z)
	_add_one_cardinal("-Z L", Vector3(0.0, surf_y, world_aabb.position.z - margin), Color(0.85, 0.85, 0.85, 1.0))
	# Right (+Z)
	_add_one_cardinal("+Z R", Vector3(0.0, surf_y, world_aabb.end.z + margin), Color(0.85, 0.85, 0.85, 1.0))
	# OD_DOCK
	var od_marker := get_socket_marker("OD_DOCK")
	if od_marker:
		var od_pos := od_marker.position + Vector3(0.0, CARDINAL_LABEL_Y_OFFSET, 0.0)
		_add_one_cardinal("OD_DOCK", od_pos, Color(0.75, 0.20, 0.95, 1.0))

	print("[BOARD_CARDINAL_DEBUG] 5 cardinal markers added")


func _add_one_cardinal(label_text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "Cardinal_" + label_text.replace("\n", "_")
	label.text = label_text
	label.position = pos
	label.modulate = color
	label.font_size = 18
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	for c in label.get_children():
		if c is CollisionObject3D:
			c.queue_free()
