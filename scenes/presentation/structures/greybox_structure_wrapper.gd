extends Node3D
class_name GreyboxStructureWrapper

const SOCKET_NAMES := [&"CoreCenter", &"EdgeNorth", &"EdgeEast", &"EdgeSouth", &"EdgeWest", &"Garrison0", &"VFXOrigin", &"LabelAnchor"]
const GENERATED_ART_META := &"_structure_generated_art"
var _configured := false
var _garrison_slot_active := false
var _garrison_slot_state: StringName = &"available"
var _last_profile_id: StringName = &""

func _ready() -> void: _ensure_contract()

func _ensure_contract() -> void:
	if _configured: return
	_configured = true
	var art := get_node_or_null("ArtRoot") as Node3D
	if art == null:
		art = Node3D.new(); art.name = "ArtRoot"; add_child(art)
	var sockets := get_node_or_null("Sockets") as Node3D
	if sockets == null:
		sockets = Node3D.new(); sockets.name = "Sockets"; add_child(sockets)
	for socket_name in SOCKET_NAMES:
		if sockets.get_node_or_null(NodePath(socket_name)) == null:
			var marker := Marker3D.new(); marker.name = socket_name; sockets.add_child(marker)
			if socket_name == &"CoreCenter": marker.position = Vector3.ZERO
	for root_name in ["StateRoots", "BoundsGuide"]:
		if get_node_or_null(root_name) == null:
			var root := Node3D.new(); root.name = root_name; add_child(root)

func configure_visual(profile_id: StringName, state: StringName, cell_spacing: float, level_step: float, preview: bool, profile: RefCounted, presentation_fact: Dictionary = {}) -> void:

	_ensure_contract()
	_last_profile_id = profile_id
	# Imported, script-free content belongs to the asset. Only rebuild our own geometry.
	var authored: Array[Node] = []
	var art_root := get_node("ArtRoot") as Node3D
	for child in art_root.get_children():
		var generated_owner: Variant = child.get_meta(GENERATED_ART_META, 0)
		if generated_owner is int and generated_owner == get_instance_id():
			art_root.remove_child(child); child.free()
		else:
			authored.append(child)
	var has_content := has_authored_geometry()
	for child in get_children():
		if child.name in ["GarrisonLocked", "GarrisonPedestal", "OpaqueFallbackOutline", "StateLabel", "FoundationStateLabel"]: remove_child(child); child.free()
	var core := MeshInstance3D.new()
	core.name = "ProceduralCore"
	var mesh := BoxMesh.new()
	var footprint := minf(profile.get_geometry_ratio(&"core_footprint_ratio") * cell_spacing, cell_spacing * 0.74)
	var height_ratio: float = float(profile.get_geometry_ratio(&"fortification_height_step_ratio"))
	match profile_id:
		&"p05_foundation": height_ratio = float(profile.get_geometry_ratio(&"foundation_height_step_ratio"))
		&"p13_heat_sink": height_ratio = float(profile.get_geometry_ratio(&"heat_sink_core_ratio"))
		&"p16_containment_wall": height_ratio = maxf(float(profile.get_geometry_ratio(&"containment_anchor_ratio")), 0.34)
		&"p19_core_cathedral": height_ratio = 1.45
	mesh.size = Vector3(footprint, level_step * height_ratio, footprint)
	core.position.y = mesh.size.y * 0.5
	core.mesh = mesh
	var material := _make_material(preview, state)
	core.material_override = material
	(get_node("ArtRoot") as Node).add_child(core)
	if bool(get_meta("force_material_failure", false)):
		_add_opaque_fallback_outline(footprint, mesh.size.y)
	if profile_id == &"p08_fortification":
		_add_box("ForwardGatehouse", Vector3(footprint * 0.42, level_step * 0.92, cell_spacing * 0.12), Vector3(0, level_step * 0.46, -footprint * 0.44), material)
		_add_box("WallLeft", Vector3(cell_spacing * 0.12, level_step * 0.48, cell_spacing * 0.84), Vector3(-footprint * 0.46, level_step * 0.24, 0), material)
		_add_box("WallRight", Vector3(cell_spacing * 0.12, level_step * 0.48, cell_spacing * 0.84), Vector3(footprint * 0.46, level_step * 0.24, 0), material)
		_add_box("WallRear", Vector3(cell_spacing * 0.84, level_step * 0.48, cell_spacing * 0.12), Vector3(0, level_step * 0.24, footprint * 0.46), material)
	elif profile_id == &"p13_heat_sink":
		_add_heat_sink_visuals(footprint, cell_spacing, level_step, material, profile)
	elif profile_id == &"p16_containment_wall":
		_add_containment_wall_visuals(footprint, cell_spacing, level_step, material, preview, presentation_fact, profile)
	elif profile_id == &"p19_core_cathedral":
		_add_core_cathedral_visuals(footprint, level_step, material, profile)
	# Compatibility renderer: a solid geometric marker communicates state without alpha transparency or color alone.
	var marker := MeshInstance3D.new()
	marker.name = "StateShape_%s" % state
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(footprint * (0.92 if state == &"intact" else 0.68), maxf(mesh.size.y * 0.14, 0.012), footprint * (0.12 if state in [&"damaged", &"critical", &"invalid"] else 0.92))
	marker.mesh = marker_mesh
	marker.position.y = mesh.size.y * 0.56
	marker.material_override = material
	(get_node("ArtRoot") as Node).add_child(marker)
	var label := get_node_or_null("StateLabel") as Label3D
	if label == null: label = Label3D.new(); label.name = "StateLabel"; add_child(label)
	label.text = {&"legal": "LEGAL +", &"replacement": "REPLACE <> ", &"invalid": "INVALID X", &"pending": "PENDING []"}.get(state, String(state).to_upper())
	label.position = Vector3(0, mesh.size.y + 0.08, 0)
	_add_foundation_state_label(state, mesh.size.y, presentation_fact)
	var sockets := get_node("Sockets") as Node3D
	var half := footprint * 0.5
	var positions := {&"EdgeNorth": Vector3(0, 0, -half), &"EdgeEast": Vector3(half, 0, 0), &"EdgeSouth": Vector3(0, 0, half), &"EdgeWest": Vector3(-half, 0, 0), &"Garrison0": Vector3(0, mesh.size.y, 0), &"VFXOrigin": Vector3(0, mesh.size.y, 0), &"LabelAnchor": Vector3(0, mesh.size.y + 0.06, 0)}
	if not has_content:
		for socket_name in positions: (sockets.get_node(NodePath(socket_name)) as Node3D).position = positions[socket_name]
	_refresh_garrison_slot_visual()
	# Rotate visible fortification around its core; edge sockets retain absolute names.
	var footprint_fact: Dictionary = presentation_fact.get("core", presentation_fact)
	var cells: Array = footprint_fact.get("footprint_cells", [])
	var art := get_node("ArtRoot") as Node3D
	if not has_content:
		art.rotation.y = 0.0
		if profile_id == &"p08_fortification" and cells.size() == 2:
			var direction: Vector2i = cells[1] - cells[0]
			art.rotation.y = atan2(-float(direction.x), -float(direction.y))
	for child in art.get_children():
		if child not in authored:
			child.set_meta(GENERATED_ART_META, get_instance_id())
			# Keep the state shape and text; do not cover imported content with a second body.
			if child is Node3D and has_content:
				(child as Node3D).visible = String(child.name).begins_with("StateShape_")
	var state_roots := get_node("StateRoots") as Node3D
	for child in state_roots.get_children(): state_roots.remove_child(child); child.free()
	var state_marker := Marker3D.new(); state_marker.name = "State_%s" % state; state_roots.add_child(state_marker)
	for control_name in ["StateLabel", "FoundationStateLabel", "OpaqueFallbackOutline"]:
		var control := get_node_or_null(NodePath(control_name))
		if control != null: control.set_meta(GENERATED_ART_META, get_instance_id())

func has_authored_geometry() -> bool:
	var art := get_node_or_null("ArtRoot")
	return art != null and _contains_authored_mesh(art)

func _contains_authored_mesh(node: Node) -> bool:
	for child in node.get_children():
		var tag: Variant = child.get_meta(GENERATED_ART_META, 0)
		if tag is int and tag == get_instance_id(): continue
		if child is MeshInstance3D and child.mesh != null: return true
		if _contains_authored_mesh(child): return true
	return false

func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:

	var node := MeshInstance3D.new(); node.name = node_name
	var box := BoxMesh.new(); box.size = size
	node.mesh = box; node.position = position; node.material_override = material
	(get_node("ArtRoot") as Node).add_child(node)
	return node


func _add_heat_sink_visuals(footprint: float, cell_spacing: float, level_step: float, material: Material, profile: RefCounted) -> void:
	var cooling_ring := MeshInstance3D.new()
	cooling_ring.name = "CoolingRing"
	var ring := CylinderMesh.new()
	var ring_radius := cell_spacing * float(profile.get_geometry_ratio(&"cooling_ring_ratio")) * 0.5
	ring.top_radius = ring_radius
	ring.bottom_radius = ring_radius
	ring.height = maxf(level_step * 0.08, 0.018)
	ring.radial_segments = 28
	cooling_ring.mesh = ring
	cooling_ring.position.y = level_step * 0.28
	cooling_ring.material_override = material
	(get_node("ArtRoot") as Node).add_child(cooling_ring)
	_add_box("StabilityLockBand", Vector3(footprint * 0.92, maxf(level_step * 0.07, 0.014), footprint * 0.18), Vector3(0.0, level_step * 0.15, 0.0), material)


func _add_containment_wall_visuals(footprint: float, cell_spacing: float, level_step: float, material: Material, preview: bool, fact: Dictionary, profile: RefCounted) -> void:
	var anchor_ratio := float(profile.get_geometry_ratio(&"containment_anchor_ratio"))
	_add_box("WallAnchorCore", Vector3(footprint * anchor_ratio, level_step * 0.42, footprint * anchor_ratio), Vector3(0.0, level_step * 0.21, 0.0), material)
	var edge := StringName(str(fact.get("orientation_edge", &"north")))
	if edge not in [&"north", &"east", &"south", &"west"]:
		edge = &"north"
	var long := cell_spacing * float(profile.get_geometry_ratio(&"wall_length_ratio"))
	var thick := cell_spacing * float(profile.get_geometry_ratio(&"wall_thickness_ratio"))
	var panel_size := Vector3(long, level_step * 0.82, thick) if edge in [&"north", &"south"] else Vector3(thick, level_step * 0.82, long)
	var panel_position := Vector3(0.0, level_step * 0.41, 0.0)
	if edge == &"north": panel_position.z = -footprint * 0.48
	elif edge == &"east": panel_position.x = footprint * 0.48
	elif edge == &"south": panel_position.z = footprint * 0.48
	else: panel_position.x = -footprint * 0.48
	_add_box("OrientedWallPanel", panel_size, panel_position, material)
	if not preview:
		return
	var states := Node3D.new()
	states.name = "OrientationStates"
	(get_node("ArtRoot") as Node).add_child(states)
	var legal: Array = fact.get("legal_orientation_edges", [])
	for candidate: StringName in [&"north", &"east", &"south", &"west"]:
		var marker := Label3D.new()
		marker.name = "Edge_%s" % candidate
		marker.text = "◆" if candidate == edge else ("＋" if candidate in legal else "×")
		marker.modulate = Color("#F4C95D") if candidate == edge else (Color("#54E39A") if candidate in legal else Color("#D85B65"))
		marker.position = {
			&"north": Vector3(0.0, level_step * 0.16, -footprint * 0.58),
			&"east": Vector3(footprint * 0.58, level_step * 0.16, 0.0),
			&"south": Vector3(0.0, level_step * 0.16, footprint * 0.58),
			&"west": Vector3(-footprint * 0.58, level_step * 0.16, 0.0),
		}[candidate]
		states.add_child(marker)


func _add_core_cathedral_visuals(footprint: float, level_step: float, material: Material, profile: RefCounted) -> void:
	var column_ratio := float(profile.get_geometry_ratio(&"cathedral_column_ratio"))
	var core_ratio := float(profile.get_geometry_ratio(&"cathedral_core_ratio"))
	_add_box("FoundationColumn", Vector3(footprint * column_ratio, level_step * 1.55, footprint * column_ratio), Vector3(0.0, -level_step * 0.44, 0.0), material)
	_add_box("WonderCore", Vector3(footprint * core_ratio, level_step * 0.72, footprint * core_ratio), Vector3(0.0, level_step * 1.05, 0.0), material)


func _add_foundation_state_label(state: StringName, visual_height: float, fact: Dictionary) -> void:
	var foundation_state := StringName(str(fact.get("foundation_state", state)))
	var phase := StringName(str(fact.get("recovery_window_phase", &"")))
	var visual_state := state
	if foundation_state == &"undermined":
		visual_state = &"undermined_active" if phase == &"active_owner_turn" else &"undermined_waiting"
	elif foundation_state == &"collapse_due":
		visual_state = &"collapse_due"
	elif foundation_state == &"stable" and state not in [&"legal", &"replacement", &"invalid", &"pending", &"replacement_before"]:
		visual_state = &"stable"
	var texts := {
		&"stable": "◇ 地形稳定",
		&"undermined_waiting": "┄ 等待所属方完整回合",
		&"undermined_active": "! 本回合结束坍塌 · 1",
		&"collapse_due": "× 坍塌到期",
	}
	if not texts.has(visual_state):
		return
	var label := Label3D.new()
	label.name = "FoundationStateLabel"
	label.text = texts[visual_state]
	label.position = Vector3(0.0, visual_height + 0.16, 0.0)
	label.modulate = {
		&"stable": Color("#63BFF2"),
		&"undermined_waiting": Color("#F0A14A"),
		&"undermined_active": Color("#EC704E"),
		&"collapse_due": Color("#D85B65"),
	}[visual_state]
	add_child(label)

func _make_material(preview: bool, state: StringName) -> StandardMaterial3D:

	var material := StandardMaterial3D.new()
	var colors := {&"legal": Color("#54E39A"), &"replacement": Color("#F4C95D"), &"replacement_before": Color(0.52, 0.58, 0.62, 0.42), &"invalid": Color("#D85B65"), &"pending": Color("#F4C95D"), &"stable": Color("#63BFF2"), &"undermined_waiting": Color("#F0A14A"), &"undermined_active": Color("#EC704E"), &"collapse_due": Color("#D85B65")}
	var forced_failure := bool(get_meta("force_material_failure", false))
	material.albedo_color = Color("#29333B") if forced_failure else colors.get(state, Color("#47616D"))
	if material.albedo_color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = preview and not forced_failure
	material.emission = material.albedo_color
	return material

func _add_opaque_fallback_outline(footprint: float, height: float) -> void:

	var outline := Node3D.new(); outline.name = "OpaqueFallbackOutline"; add_child(outline)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#F2F5FF")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var half := footprint * 0.53
	for bar in [
		{"name":"OutlineNorth", "size":Vector3(footprint * 1.08, 0.018, 0.025), "position":Vector3(0, height + 0.012, -half)},
		{"name":"OutlineSouth", "size":Vector3(footprint * 1.08, 0.018, 0.025), "position":Vector3(0, height + 0.012, half)},
		{"name":"OutlineEast", "size":Vector3(0.025, 0.018, footprint * 1.08), "position":Vector3(half, height + 0.012, 0)},
		{"name":"OutlineWest", "size":Vector3(0.025, 0.018, footprint * 1.08), "position":Vector3(-half, height + 0.012, 0)}
	]:
		var line := MeshInstance3D.new(); line.name = bar["name"]
		var mesh := BoxMesh.new(); mesh.size = bar["size"]
		line.mesh = mesh; line.position = bar["position"]; line.material_override = material
		outline.add_child(line)

func get_socket(socket_name: StringName) -> Node3D:

	_ensure_contract()
	return get_node_or_null(NodePath("Sockets/%s" % socket_name)) as Node3D


func set_garrison_slot_active(active: bool, state: StringName = &"available") -> void:

	_garrison_slot_active = active
	_garrison_slot_state = state
	_refresh_garrison_slot_visual()


func _refresh_garrison_slot_visual() -> void:

	for node_name in ["GarrisonLocked", "GarrisonPedestal"]:
		var existing := get_node_or_null(node_name)
		if existing != null:
			remove_child(existing)
			existing.queue_free()
	if _last_profile_id != &"p08_fortification":
		return
	var socket := get_node_or_null("Sockets/Garrison0") as Node3D
	var socket_position := socket.position if socket != null else Vector3(0.0, 0.08, 0.0)
	if not _garrison_slot_active:
		var locked := Label3D.new()
		locked.name = "GarrisonLocked"
		locked.set_meta(GENERATED_ART_META, get_instance_id())
		locked.text = "LOCKED"
		locked.position = socket_position + Vector3(0.0, 0.04, 0.0)
		add_child(locked)
		return
	var pedestal := MeshInstance3D.new()
	pedestal.name = "GarrisonPedestal"
	pedestal.set_meta(GENERATED_ART_META, get_instance_id())
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.15
	mesh.height = 0.035
	mesh.radial_segments = 20
	pedestal.mesh = mesh
	pedestal.position = socket_position + Vector3(0.0, -0.012, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#8A5960") if _garrison_slot_state == &"displaced_pending_exit" else Color("#52BFC8")
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.35
	pedestal.material_override = material
	add_child(pedestal)
