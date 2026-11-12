extends Node3D

## Phase 22E-0R2: Card Carrier Preview Controls
## T: top-down view
## S: toggle socket visual
## Arrow keys: orbit
## Mouse wheel: zoom
## ESC: quit

var _yaw := 30.0
var _pitch := 40.0
var _dist := 2.8
var _center := Vector3(0.0, 0.06, 0.0)
var _carrier: Node = null


func _ready() -> void:
	_carrier = get_node_or_null("CardCarrier")
	print("[Preview] Controls: T=top, S=socket, Arrows=orbit, Wheel=zoom, ESC=quit")
	if _carrier:
		await get_tree().process_frame
		_print_status()
	else:
		printerr("[Preview] CardCarrier not found")
	_sync_from_camera()


func _sync_from_camera() -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return
	var off := cam.global_position - _center
	_dist = off.length()
	if _dist > 0.01:
		_pitch = rad_to_deg(asin(clampf(off.y / _dist, -1.0, 1.0)))
		_yaw = rad_to_deg(atan2(off.x, off.z))


func _print_status() -> void:
	if not _carrier:
		return
	var b := _has_child_model("BaseRoot")
	var f := _has_child_model("FrameRoot")
	var g := _has_child_model("GlowRoot")
	var sv := _carrier.get_node_or_null("SocketVisualRoot")
	var s := _has_child_model("SocketVisualRoot")
	var sv_vis: bool = sv.visible if sv else false
	print("[Preview] Base=%s Frame=%s Glow=%s Socket=%s(vis=%s)" % ["OK" if b else "NO", "OK" if f else "NO", "OK" if g else "NO", "OK" if s else "NO", str(sv_vis)])


func _has_child_model(parent_name: String) -> bool:
	if not _carrier:
		return false
	var p := _carrier.get_node_or_null(parent_name)
	return p != null and p.get_child_count() > 0


func _apply_preset(name: String) -> void:
	match name:
		"top":
			_pitch = 89.0; _yaw = 0.0; _dist = 2.0; _center = Vector3(0, 0.06, 0)
		"three_quarter":
			_pitch = 40.0; _yaw = 30.0; _dist = 2.8; _center = Vector3(0, 0.06, 0)
		"side":
			_pitch = 15.0; _yaw = 0.0; _dist = 3.0; _center = Vector3(0, 0.06, 0)
	_update_camera()
	print("[Preview] Camera preset: %s (yaw=%.0f pitch=%.0f dist=%.1f)" % [name, _yaw, _pitch, _dist])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				_apply_preset("top")
				return
			KEY_R:
				_apply_preset("three_quarter")
				return
			KEY_E:
				_apply_preset("side")
				return
			KEY_S:
				if _carrier and _carrier.has_method("toggle_socket_visual"):
					_carrier.toggle_socket_visual()
				_print_status()
				return
			KEY_ESCAPE:
				get_tree().quit()
				return
			KEY_LEFT:  _yaw -= 10.0; _update_camera()
			KEY_RIGHT: _yaw += 10.0; _update_camera()
			KEY_UP:    _pitch = min(85.0, _pitch + 10.0); _update_camera()
			KEY_DOWN:  _pitch = max(5.0, _pitch - 10.0); _update_camera()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = max(0.6, _dist - 0.3); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = min(8.0, _dist + 0.3); _update_camera()


func _update_camera() -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if not cam:
		return
	var yr := deg_to_rad(_yaw)
	var pr := deg_to_rad(_pitch)
	var off := Vector3(sin(yr) * cos(pr) * _dist, sin(pr) * _dist, cos(yr) * cos(pr) * _dist)
	cam.global_position = _center + off
	cam.look_at(_center, Vector3.UP)
