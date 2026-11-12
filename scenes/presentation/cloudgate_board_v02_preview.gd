extends Node3D

const BOARD_PATH := "res://assets/table/3d/cloudgate_battle_board_v02_candidate.glb"
const EXPECTED_SIZE := Vector3(10.0, 0.6, 6.0)
const SIZE_TOLERANCE := 0.03

var _yaw := 28.0
var _pitch := 42.0
var _distance := 12.5
var _target := Vector3(0.0, 0.2, 0.0)
var _board: Node3D


func _ready() -> void:
	_load_board()
	_add_socket_markers()
	_update_camera()
	print("[BOARD_V02_PREVIEW] R=three-quarter T=top P=player B=boss arrows=orbit wheel=zoom")


func _load_board() -> void:
	if not ResourceLoader.exists(BOARD_PATH, "PackedScene"):
		push_error("[BOARD_V02_PREVIEW] candidate missing: %s" % BOARD_PATH)
		return
	var scene := load(BOARD_PATH) as PackedScene
	if scene == null:
		push_error("[BOARD_V02_PREVIEW] candidate load failed")
		return
	_board = scene.instantiate() as Node3D
	if _board == null:
		push_error("[BOARD_V02_PREVIEW] candidate instantiate failed")
		return
	_board.name = "CloudGateBoardV02Candidate"
	get_node("BoardRoot").add_child(_board)
	var bounds := _merged_world_aabb(_board)
	var delta := Vector3(
		absf(bounds.size.x - EXPECTED_SIZE.x),
		absf(bounds.size.y - EXPECTED_SIZE.y),
		absf(bounds.size.z - EXPECTED_SIZE.z)
	)
	var passed := maxf(delta.x, maxf(delta.y, delta.z)) <= SIZE_TOLERANCE and absf(bounds.position.y) <= SIZE_TOLERANCE
	print("[BOARD_V02_PREVIEW] aabb_pos=%s size=%s delta=%s" % [bounds.position, bounds.size, delta])
	print("[BOARD_V02_PREVIEW] contract=%s" % ("PASS" if passed else "FAIL"))


func _merged_world_aabb(root: Node) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	if meshes.is_empty():
		return AABB()
	var merged := meshes[0].global_transform * meshes[0].get_aabb()
	for index in range(1, meshes.size()):
		merged = merged.merge(meshes[index].global_transform * meshes[index].get_aabb())
	return merged


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _add_socket_markers() -> void:
	var root := get_node("SocketMarkers") as Node3D
	for side in ["P", "B"]:
		var sign_z := 1.0 if side == "P" else -1.0
		for zone in ["FRONT", "BACK"]:
			var z := 0.95 if zone == "FRONT" else 1.75
			var color := Color(0.10, 0.85, 1.0, 0.85) if side == "P" else Color(1.0, 0.30, 0.08, 0.85)
			for index in range(5):
				_add_marker(root, "%s_%s_%d" % [side, zone, index], Vector3(-3.0 + index * 1.5, 0.63, z * sign_z), color)
	# Preserve the runtime socket X/Z contract. Preview Y is lifted above the
	# candidate surface; the active runtime still owns its current 0.42/0.48 Y.
	_add_marker(root, "ACTION_SLOT", Vector3(0.0, 0.63, 0.45), Color(1.0, 0.85, 0.2, 0.9))
	_add_marker(root, "BOSS_CORE", Vector3(0.0, 0.63, -2.35), Color(1.0, 0.1, 0.25, 0.9))
	_add_marker(root, "PLAYER_DECK", Vector3(4.05, 0.63, 1.72), Color(0.1, 0.75, 1.0, 0.9))
	_add_marker(root, "PLAYER_GY", Vector3(4.05, 0.63, 0.96), Color(0.1, 0.55, 0.75, 0.9))
	_add_marker(root, "BOSS_DECK", Vector3(4.05, 0.63, -1.72), Color(1.0, 0.45, 0.1, 0.9))
	_add_marker(root, "BOSS_GY", Vector3(4.05, 0.63, -0.96), Color(0.75, 0.25, 0.1, 0.9))
	_add_marker(root, "OD_DOCK", Vector3(-4.05, 0.63, 0.96), Color(0.75, 0.2, 0.95, 0.9))
	print("[BOARD_V02_PREVIEW] socket_markers=%d" % root.get_child_count())


func _add_marker(parent: Node3D, marker_name: String, position: Vector3, color: Color) -> void:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	marker.mesh = mesh
	marker.position = position
	parent.add_child(marker)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_yaw = 28.0; _pitch = 42.0; _distance = 12.5
			KEY_T:
				_yaw = 0.0; _pitch = 89.0; _distance = 12.0
			KEY_P:
				_yaw = 0.0; _pitch = 28.0; _distance = 12.5
			KEY_B:
				_yaw = 180.0; _pitch = 28.0; _distance = 12.5
			KEY_LEFT:
				_yaw -= 10.0
			KEY_RIGHT:
				_yaw += 10.0
			KEY_UP:
				_pitch = minf(85.0, _pitch + 8.0)
			KEY_DOWN:
				_pitch = maxf(8.0, _pitch - 8.0)
		_update_camera()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(7.0, _distance - 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(18.0, _distance + 0.6)
		_update_camera()


func _update_camera() -> void:
	var camera := get_node("Camera3D") as Camera3D
	var yaw_r := deg_to_rad(_yaw)
	var pitch_r := deg_to_rad(_pitch)
	var offset := Vector3(
		sin(yaw_r) * cos(pitch_r) * _distance,
		sin(pitch_r) * _distance,
		cos(yaw_r) * cos(pitch_r) * _distance
	)
	camera.position = _target + offset
	camera.look_at(_target, Vector3.UP)
