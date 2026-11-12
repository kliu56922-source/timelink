extends Node3D
class_name MonsterSummonHologramPawn

## Presentation-only monster identity. This node owns no combat, board, or input state.

const COLOR_CYAN := Color(0.24, 0.92, 0.98, 0.66)
const COLOR_GOLD := Color(1.0, 0.76, 0.20, 0.70)
const COLOR_RED := Color(0.96, 0.24, 0.24, 0.70)
const COLOR_COLD_WHITE := Color(0.82, 0.92, 1.0, 0.62)
const ROTATION_RADIANS_PER_SECOND := 0.7

var _material: StandardMaterial3D = null
var _visual_state: StringName = &"fallback"
var _reduced_motion := true
var _built := false


func _init() -> void:
	set_meta("presentation_only", true)
	set_process(false)


func configure(card: CardData, visual_state: StringName, reduced_motion: bool) -> void:
	_build_meshes()
	_reduced_motion = reduced_motion or card == null
	_visual_state = _resolved_visual_state(card, visual_state)
	_apply_visual_state()
	var identity := get_node_or_null(NodePath("IdentityBadge")) as Label3D
	if identity != null:
		identity.text = card.card_id if card != null and not card.card_id.is_empty() else "UNIT"
	rotation = Vector3.ZERO
	set_process(not _reduced_motion)


func get_debug_snapshot() -> Dictionary:
	return {
		"presentation_only": bool(get_meta("presentation_only", false)),
		"visual_state": _visual_state,
		"active_tweens": 0,
		"motion_processing": not _reduced_motion,
		"mesh_count": find_children("*", "MeshInstance3D", true, false).size(),
	}


func _process(delta: float) -> void:
	rotate_y(ROTATION_RADIANS_PER_SECOND * delta)


func _resolved_visual_state(card: CardData, requested: StringName) -> StringName:
	if card == null:
		return &"fallback"
	match requested:
		&"drag", &"hover", &"pending", &"invalid":
			return requested
	return &"fallback"


func _apply_visual_state() -> void:
	if _material == null:
		return
	var color := COLOR_COLD_WHITE
	match _visual_state:
		&"drag", &"hover":
			color = COLOR_CYAN
		&"pending":
			color = COLOR_GOLD
		&"invalid":
			color = COLOR_RED
	_material.albedo_color = color
	_material.emission = Color(color.r, color.g, color.b, 1.0)


func _build_meshes() -> void:
	if _built:
		return
	_built = true
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.emission_energy_multiplier = 1.15

	var base := MeshInstance3D.new()
	base.name = "PawnBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.24
	base_mesh.bottom_radius = 0.30
	base_mesh.height = 0.08
	base.mesh = base_mesh
	base.material_override = _material
	add_child(base)

	var body := MeshInstance3D.new()
	body.name = "PawnBody"
	body.position = Vector3.UP * 0.22
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.11
	body_mesh.bottom_radius = 0.20
	body_mesh.height = 0.36
	body.mesh = body_mesh
	body.material_override = _material
	add_child(body)

	var head := MeshInstance3D.new()
	head.name = "PawnHead"
	head.position = Vector3.UP * 0.46
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.26
	head.mesh = head_mesh
	head.material_override = _material
	add_child(head)

	var socket := Node3D.new()
	socket.name = "ModelSocket3D"
	add_child(socket)

	var identity := Label3D.new()
	identity.name = "IdentityBadge"
	identity.position = Vector3(0.0, 0.68, 0.0)
	identity.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	identity.no_depth_test = true
	identity.fixed_size = true
	identity.font_size = 16
	identity.outline_size = 2
	add_child(identity)
