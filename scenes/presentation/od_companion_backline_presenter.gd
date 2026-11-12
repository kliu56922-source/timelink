extends Node3D
class_name ODCompanionBacklinePresenter

## Phase 26D-R1: OD 伙伴后场表现器（只读，棋盘安装版）
##
## 视觉设备通过配置偏移安装到棋盘上：墓地/牌库在右侧台座，OD 在左侧圆形结构。
## 逻辑 Socket 保持不变，Presenter 只消费只读快照。

const STATION_GRAVEYARD: StringName = &"player_graveyard"
const STATION_COMPANION: StringName = &"od_companion"
const STATION_DECK: StringName = &"player_deck"

var _configured := false
var _profile: RefCounted = null
var _collision_layer: int = 0
var _anchor_map: Dictionary = {}
var _station_roots: Dictionary = {}
var _click_areas: Dictionary = {}
var _station_labels: Dictionary = {}
var _companion_charge_bar: MeshInstance3D = null
var _graveyard_art_quad: MeshInstance3D = null
var _rail_points: Array[Vector3] = []
var _rail_mesh: Node3D = null
var _highlight_materials: Dictionary = {}
var _highlight_active: Dictionary = {}
var _last_snapshot: Dictionary = {}
var _prev_snapshot: Dictionary = {}
var _active_tweens: Array[Tween] = []
var _active_timers: Array[Timer] = []
var _base_transforms: Dictionary = {}


func configure(anchor_map: Dictionary, click_collision_layer: int, profile: RefCounted) -> void:
	if _configured and profile == _profile:
		return
	if _configured:
		cancel_presentations()
		_teardown_stations()
	_profile = profile
	_collision_layer = click_collision_layer
	_anchor_map = anchor_map.duplicate()
	_configured = true
	_build_stations()


func apply_snapshot(snapshot: Dictionary) -> void:
	if not _configured:
		return
	_prev_snapshot = _last_snapshot.duplicate()
	_last_snapshot = snapshot.duplicate()
	var layer_changed: bool = snapshot.get("layer", 0) != _prev_snapshot.get("layer", 0)
	var charge_changed: bool = snapshot.get("charge", 0) != _prev_snapshot.get("charge", 0)
	var gy_count_changed: bool = snapshot.get("graveyard_count", 0) != _prev_snapshot.get("graveyard_count", 0)
	var deck_count_changed: bool = snapshot.get("deck_count", 0) != _prev_snapshot.get("deck_count", 0)
	_update_station_labels()
	if layer_changed and snapshot.get("layer", 0) > _prev_snapshot.get("layer", 0):
		_play_evolution_feedback()
	if charge_changed and snapshot.get("charge", 0) > _prev_snapshot.get("charge", 0):
		_play_charge_pulse()
	if gy_count_changed:
		_play_gy_pulse()
		_update_gy_art()
	if deck_count_changed and snapshot.get("deck_count", 0) < _prev_snapshot.get("deck_count", 0):
		_play_deck_pulse()
	_apply_depth_visuals()
	_update_rail_color()


func get_interaction_anchor(kind: StringName) -> Node3D:
	if _station_roots.has(kind):
		var root: Node3D = _station_roots[kind]
		if is_instance_valid(root):
			return root
	return null


func set_interaction_highlight(kind: StringName, active: bool) -> void:
	if not _highlight_materials.has(kind):
		return
	_highlight_active[kind] = active
	var meshes: Array[Node] = []
	if _station_roots.has(kind):
		var root: Node3D = _station_roots[kind]
		if is_instance_valid(root):
			meshes = root.find_children("*", "MeshInstance3D")
	for mesh in meshes:
		if active:
			mesh.material_override = _highlight_materials[kind]
		else:
			mesh.material_override = null


func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate()


func cancel_presentations() -> void:
	for twn in _active_tweens:
		if is_instance_valid(twn):
			twn.kill()
	_active_tweens.clear()
	for tmr in _active_timers:
		if is_instance_valid(tmr):
			tmr.stop()
	_active_timers.clear()
	for kind in _highlight_active.keys():
		set_interaction_highlight(kind, false)
	_highlight_active.clear()
	for station_id in _base_transforms:
		if _station_roots.has(station_id):
			var root: Node3D = _station_roots[station_id]
			if is_instance_valid(root):
				root.global_transform = _base_transforms[station_id]
				root.scale = _get_station_scale(station_id)


# ── 站点构建（R1: 视觉偏移安装）───────────────────────────

func _build_stations() -> void:
	var order: Array[StringName] = []
	if _profile:
		order.assign(_profile.get_station_order())
	else:
		order.assign([&"player_graveyard", &"od_companion", &"player_deck"])

	var station_parents := {
		&"player_graveyard": $PlayerGraveyardStation,
		&"od_companion": $ODCompanionStation,
		&"player_deck": $PlayerDeckStation,
	}

	_rail_points.clear()

	for station_id in order:
		var anchor: Node3D = _anchor_map.get(station_id) as Node3D
		if not anchor or not is_instance_valid(anchor):
			continue
		var parent: Node3D = station_parents.get(station_id) as Node3D
		if not parent:
			continue

		# R1: 应用视觉偏移计算最终位置
		var offset: Vector3 = Vector3.ZERO
		if _profile and _profile.has_method("get_station_visual_offset"):
			offset = _profile.get_station_visual_offset(station_id)
		var visual_transform := anchor.global_transform * Transform3D(Basis.IDENTITY, offset)
		parent.global_transform = visual_transform
		_station_roots[station_id] = parent
		_base_transforms[station_id] = parent.global_transform

		var station_scale := _get_station_scale(station_id)
		parent.scale = station_scale

		_build_station_visuals(station_id, parent)
		_build_click_area(station_id, parent)
		_rail_points.append(parent.global_position)

	_build_energy_rail()
	_station_roots[&"player_graveyard"] = station_parents[&"player_graveyard"]
	_station_roots[&"od_companion"] = station_parents[&"od_companion"]
	_station_roots[&"player_deck"] = station_parents[&"player_deck"]


func _get_station_scale(station_id: StringName) -> Vector3:
	var s: float = 1.0
	if _profile:
		s = _profile.get_station_scale(station_id)
	return Vector3(s, s, s)


func _build_station_visuals(station_id: StringName, parent: Node3D) -> void:
	match station_id:
		&"player_graveyard": _build_graveyard_visuals(parent)
		&"od_companion": _build_companion_visuals(parent)
		&"player_deck": _build_deck_visuals(parent)


# ── R1 墓地：薄卡面+边框 ───────────────────────────────

func _build_graveyard_visuals(parent: Node3D) -> void:
	var card_face := _make_quad("GY_CardFace", Vector2(0.42, 0.34))
	card_face.position = Vector3(0, 0.003, 0)
	var cf_mat := StandardMaterial3D.new()
	cf_mat.albedo_color = Color(0.22, 0.18, 0.26, 1)
	cf_mat.metallic = 0.05; cf_mat.roughness = 0.85
	card_face.material_override = cf_mat
	parent.add_child(card_face)
	_graveyard_art_quad = card_face

	var frame := _make_box("GY_Frame", Vector3(0.48, 0.015, 0.40))
	frame.position = Vector3(0, 0.0, 0)
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.35, 0.30, 0.38, 1)
	f_mat.metallic = 0.6; f_mat.roughness = 0.4
	frame.material_override = f_mat
	parent.add_child(frame)

	var label := _make_surface_plaque("GY_Plaque", 12, Color(0.8, 0.78, 0.82, 1), parent)
	_station_labels[&"player_graveyard"] = label


# ── R1 OD：圆形机械结构 ─────────────────────────────────

func _build_companion_visuals(parent: Node3D) -> void:
	var outer_ring := _make_cylinder("OD_OuterRing", 0.32, 0.32, 0.06)
	outer_ring.position = Vector3(0, 0.01, 0)
	var or_mat := StandardMaterial3D.new()
	or_mat.albedo_color = Color(0.18, 0.16, 0.22, 1)
	or_mat.metallic = 0.7; or_mat.roughness = 0.35
	or_mat.emission_enabled = true
	or_mat.emission = Color(0.2, 0.5, 0.6, 1)
	or_mat.emission_energy_multiplier = 0.4
	outer_ring.material_override = or_mat
	parent.add_child(outer_ring)

	var inner_pillar := _make_cylinder("OD_InnerPillar", 0.12, 0.12, 0.22)
	inner_pillar.position = Vector3(0, 0.14, 0)
	var ip_mat := StandardMaterial3D.new()
	ip_mat.albedo_color = Color(0.25, 0.22, 0.30, 1)
	ip_mat.emission_enabled = true
	ip_mat.emission = Color(0.25, 0.55, 0.65, 1)
	ip_mat.emission_energy_multiplier = 0.4
	inner_pillar.material_override = ip_mat
	parent.add_child(inner_pillar)
	_companion_charge_bar = inner_pillar

	var bot_ring := _make_cylinder("OD_BotRing", 0.28, 0.28, 0.03)
	bot_ring.position = Vector3(0, -0.01, 0)
	var br_mat := StandardMaterial3D.new()
	br_mat.albedo_color = Color(0.22, 0.20, 0.26, 1)
	br_mat.metallic = 0.65; br_mat.roughness = 0.4
	bot_ring.material_override = br_mat
	parent.add_child(bot_ring)

	var label := _make_surface_plaque("OD_Plaque", 14, Color.WHITE, parent)
	_station_labels[&"od_companion"] = label

	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(0.2, 0.6, 0.7, 1)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(0.3, 0.7, 0.8, 1)
	hl_mat.emission_energy_multiplier = 1.2
	_highlight_materials[&"od_companion"] = hl_mat


# ── R1 牌库：N层牌堆 ────────────────────────────────────

func _build_deck_visuals(parent: Node3D) -> void:
	var stack_count: int = 4
	if _profile and _profile.has_method("get_deck_stack_layers"):
		stack_count = _profile.get_deck_stack_layers()
	var card_w: float = 0.35; var card_h: float = 0.28; var y_step: float = 0.004
	for i in range(stack_count):
		var card := _make_quad("Deck_Card_%d" % i, Vector2(card_w, card_h))
		card.position = Vector3(0, 0.003 + i * y_step, 0)
		var c_mat := StandardMaterial3D.new()
		var brightness: float = 0.18 + (0.03 * i)
		c_mat.albedo_color = Color(brightness, brightness, brightness + 0.04, 1)
		c_mat.metallic = 0.08; c_mat.roughness = 0.8
		card.material_override = c_mat
		parent.add_child(card)

	var label := _make_surface_plaque("Deck_Plaque", 11, Color(0.75, 0.75, 0.80, 1), parent)
	_station_labels[&"player_deck"] = label


func _make_surface_plaque(p_name: String, p_font_size: int, p_modulate: Color, p_parent: Node3D) -> Label3D:
	var label := Label3D.new()
	label.name = p_name
	label.position = Vector3(0, 0.005, 0)
	label.font_size = p_font_size
	label.outline_size = 1
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.modulate = p_modulate
	var plaque_rot: float = -90.0
	if _profile and _profile.has_method("get_surface_plaque_rotation_degrees_x"):
		plaque_rot = _profile.get_surface_plaque_rotation_degrees_x()
	label.rotation_degrees = Vector3(plaque_rot, 0, 0)
	p_parent.add_child(label)
	return label


func _build_click_area(station_id: StringName, parent: Node3D) -> void:
	var area := Area3D.new()
	area.name = "BacklineClickArea"
	area.collision_layer = _collision_layer
	area.collision_mask = 0
	area.monitoring = true
	area.monitorable = true
	area.set_meta("target_kind", station_id)
	area.set_meta("backline_station", true)
	parent.add_child(area)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "ClickShape"
	var box := BoxShape3D.new()
	box.size = _profile.get_hitbox_size() if _profile else Vector3(1.0, 0.45, 1.0)
	shape_node.shape = box
	shape_node.disabled = false
	area.add_child(shape_node)
	_click_areas[station_id] = area


func _build_energy_rail() -> void:
	if _rail_points.size() < 2: return
	var rail_parent := $EnergyRail as Node3D
	if not rail_parent: return
	# Straight provisional rails cross the playable field when the stations are
	# mounted to their physical board fixtures. Keep the geometry available for
	# a future edge-routed effect, but do not render it in the battle view.
	rail_parent.visible = false
	for child in rail_parent.get_children(): child.queue_free()
	for i in range(_rail_points.size() - 1):
		var a: Vector3 = _rail_points[i]; var b: Vector3 = _rail_points[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var dir: Vector3 = (b - a).normalized()
		var length: float = a.distance_to(b)
		var rail_seg := _make_box("RailSeg_%d" % i, Vector3(0.04, 0.02, length))
		rail_seg.position = mid
		if dir.length() > 0.001:
			rail_seg.rotation.y = atan2(dir.x, dir.z)
		var rail_mat := StandardMaterial3D.new()
		rail_mat.albedo_color = Color(0.15, 0.3, 0.35, 1)
		rail_mat.emission_enabled = true
		rail_mat.emission = Color(0.2, 0.5, 0.6, 1)
		rail_mat.emission_energy_multiplier = 0.3
		rail_seg.material_override = rail_mat
		rail_parent.add_child(rail_seg)
	_rail_mesh = rail_parent


# ── 标签更新 ──────────────────────────────────────────────

func _update_station_labels() -> void:
	var gy_label: Label3D = _station_labels.get(&"player_graveyard") as Label3D
	if gy_label and is_instance_valid(gy_label):
		gy_label.text = "墓地 %d" % _last_snapshot.get("graveyard_count", 0)
	var comp_label: Label3D = _station_labels.get(&"od_companion") as Label3D
	if comp_label and is_instance_valid(comp_label):
		comp_label.text = "L%d  充能 %d/%d" % [_last_snapshot.get("layer", 1), _last_snapshot.get("charge", 0), _last_snapshot.get("capacity", 4)]
		if _profile:
			comp_label.modulate = _profile.get_layer_color(_last_snapshot.get("layer", 1))
	var deck_label: Label3D = _station_labels.get(&"player_deck") as Label3D
	if deck_label and is_instance_valid(deck_label):
		deck_label.text = "牌库 %d" % _last_snapshot.get("deck_count", 0)


# ── 视觉反馈 ──────────────────────────────────────────────

func _play_evolution_feedback() -> void:
	if not _profile: return
	var root: Node3D = _station_roots.get(&"od_companion") as Node3D
	if not root or not is_instance_valid(root): return
	var duration: float = _profile.get_evolution_seconds()
	var twn := create_tween(); twn.set_parallel(true)
	_active_tweens.append(twn)
	twn.tween_property(root, "scale", root.scale * 1.2, duration * 0.3)
	twn.tween_property(root, "scale", root.scale, duration * 0.7).set_delay(duration * 0.3)
	if _companion_charge_bar and is_instance_valid(_companion_charge_bar):
		var mat: StandardMaterial3D = _companion_charge_bar.material_override as StandardMaterial3D
		if mat:
			twn.tween_property(mat, "emission_energy_multiplier", mat.emission_energy_multiplier * 3.0, duration * 0.3)
			twn.tween_property(mat, "emission_energy_multiplier", mat.emission_energy_multiplier, duration * 0.7).set_delay(duration * 0.3)


func _play_charge_pulse() -> void:
	if not _profile: return
	var root: Node3D = _station_roots.get(&"od_companion") as Node3D
	if not root or not is_instance_valid(root): return
	var twn := create_tween(); _active_tweens.append(twn)
	var orig_y := root.position.y
	twn.tween_property(root, "position:y", orig_y + 0.08, _profile.get_pulse_seconds() * 0.5)
	twn.tween_property(root, "position:y", orig_y, _profile.get_pulse_seconds() * 0.5)


func _play_gy_pulse() -> void:
	var root: Node3D = _station_roots.get(&"player_graveyard") as Node3D
	if not root or not is_instance_valid(root) or not _profile: return
	var twn := create_tween(); _active_tweens.append(twn)
	var orig_scale := root.scale
	twn.tween_property(root, "scale", orig_scale * 1.08, _profile.get_pulse_seconds() * 0.5)
	twn.tween_property(root, "scale", orig_scale, _profile.get_pulse_seconds() * 0.5)


func _play_deck_pulse() -> void:
	var root: Node3D = _station_roots.get(&"player_deck") as Node3D
	if not root or not is_instance_valid(root) or not _profile: return
	var twn := create_tween(); _active_tweens.append(twn)
	var orig_scale := root.scale
	twn.tween_property(root, "scale", orig_scale * 1.05, _profile.get_pulse_seconds() * 0.5)
	twn.tween_property(root, "scale", orig_scale, _profile.get_pulse_seconds() * 0.5)


func _update_gy_art() -> void:
	if not _graveyard_art_quad or not is_instance_valid(_graveyard_art_quad): return
	var tex = _last_snapshot.get("graveyard_latest_art", null)
	if tex != null and tex is Texture2D:
		var mat: StandardMaterial3D = _graveyard_art_quad.material_override as StandardMaterial3D
		if not mat: mat = StandardMaterial3D.new()
		var dup_mat := mat.duplicate() as StandardMaterial3D
		dup_mat.albedo_texture = tex
		_graveyard_art_quad.material_override = dup_mat
	else:
		var has_name: bool = _last_snapshot.get("graveyard_latest_name", "") != ""
		var mat: StandardMaterial3D = _graveyard_art_quad.material_override as StandardMaterial3D
		if mat:
			mat.albedo_texture = null
			mat.albedo_color = Color(0.35, 0.3, 0.4, 1) if has_name else Color(0.22, 0.18, 0.26, 1)


# ── Depth 视觉效果（R1: 从缓存基础变换恢复）───────────────

func _apply_depth_visuals() -> void:
	var depth: int = _last_snapshot.get("depth", 0)
	var backlash: bool = _last_snapshot.get("backlash", false)
	var zone: String = _last_snapshot.get("depth_zone", "Stable")
	var root: Node3D = _station_roots.get(&"od_companion") as Node3D
	if not root or not is_instance_valid(root) or not _profile: return

	# R1: 每帧从缓存的 _base_transforms 恢复，防止累计漂移
	var station_id: StringName = &"od_companion"
	if _base_transforms.has(station_id):
		root.global_transform = _base_transforms[station_id]
		root.scale = _get_station_scale(station_id)

	if depth > 0 and (zone == "Warning" or zone == "Backlash" or backlash):
		var amp: float = _profile.get_depth_jitter_amplitude()
		root.position += Vector3(randf_range(-amp, amp), randf_range(-amp * 0.5, amp * 0.5), randf_range(-amp, amp))


func _update_rail_color() -> void:
	if not _rail_mesh or not is_instance_valid(_rail_mesh) or not _profile: return
	var color: Color = _profile.get_layer_color(_last_snapshot.get("layer", 1))
	for child in _rail_mesh.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
			if mat:
				mat.emission = color
				mat.emission_energy_multiplier = 0.3 + _last_snapshot.get("layer", 1) * 0.15


# ── 生命周期 ──────────────────────────────────────────────

func _exit_tree() -> void:
	cancel_presentations()
	_teardown_stations()


func _teardown_stations() -> void:
	cancel_presentations()
	_station_roots.clear(); _click_areas.clear(); _station_labels.clear()
	_highlight_materials.clear(); _highlight_active.clear(); _base_transforms.clear()
	_rail_points.clear()
	_companion_charge_bar = null; _graveyard_art_quad = null; _rail_mesh = null
	_last_snapshot.clear(); _prev_snapshot.clear()
	_configured = false


# ── 帮助方法 ──────────────────────────────────────────────

func _make_box(node_name: String, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.name = node_name
	var mesh := BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	return mi


func _make_cylinder(node_name: String, top_r: float, bottom_r: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r; mesh.bottom_radius = bottom_r; mesh.height = height
	mi.mesh = mesh
	return mi


func _make_quad(node_name: String, size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.name = node_name
	var mesh := QuadMesh.new(); mesh.size = size; mi.mesh = mesh
	return mi
